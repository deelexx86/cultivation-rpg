class_name SnapshotStore
extends RefCounted
## Synchronous single-writer snapshots. Backup is recovery-only, never a menu slot.
const SCHEMA := 1
const CONTENT := "p1-fixture-1"
const BUILD := "0.1.0-p1"
const MAX_BYTES := 16777216
const STAGES: Array[String] = ["before_write", "partial_write", "after_flush", "after_verify", "partial_backup", "after_backup_write", "after_backup_replace", "after_main_replace"]

var exploration_slot: bool
var material_slot: bool
var directory: String
var campaign_id: String
var sequence: int = 0
var last_error: String = ""
# Test-only fault injection. A separate process can stop here for crash verification.
var fail_at: String = ""
var crash_at: String = ""

func _init(base: String, id: String, for_exploration: bool = false, for_materials: bool = false) -> void:
	exploration_slot = for_exploration
	material_slot = for_materials
	campaign_id = id
	var valid_id := RegEx.new()
	valid_id.compile("^[a-zA-Z0-9_-]{1,64}$")
	directory = ProjectSettings.globalize_path(base.path_join(id)) if valid_id.search(id) != null else ""

func path(name: String) -> String:
	return directory.path_join(name)

func fault(stage: String) -> bool:
	if crash_at == stage:
		# Deliberately leave the process waiting at a durable protocol boundary.
		# The external harness terminates this process, not a graceful Godot quit.
		print("P1_CRASH_READY:", stage)
		while true:
			OS.delay_msec(50)
	if fail_at == stage:
		last_error = "Injected I/O failure: " + stage
		return true
	return false

static func pack(state: CampaignState, number: int) -> String:
	var payload := JSON.stringify(state.encode())
	var header := {"schema": SCHEMA, "content": CONTENT, "build": BUILD, "campaign_id": state.campaign_id, "sequence": number, "rng_algorithm": "sha256-keyed-v1"}
	if not state.exploration.is_empty():
		header.merge({"schema": 2, "content": "white-sedge-1", "build": "p2"}, true)
	if not state.materials.is_empty():
		header.merge({"schema": 3, "content": "white-sedge-materials-1", "build": "p3"}, true)
	return JSON.stringify({"header": header, "payload": payload, "checksum": digest(header, payload)})

static func digest(header: Dictionary, payload: String) -> String:
	var canonical := header.duplicate()
	canonical.schema = int(canonical.schema)
	canonical.sequence = int(canonical.sequence)
	return (JSON.stringify(canonical) + "\n" + payload).sha256_text()

func read_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"error": "missing"}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"error": "Cannot read snapshot"}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"error": "Snapshot too large"}
	var source := file.get_as_text()
	var io_error := file.get_error()
	file.close()
	if io_error != OK and io_error != ERR_FILE_EOF:
		return {"error": "Snapshot read failed"}
	var json := JSON.new()
	if json.parse(source) != OK or not json.data is Dictionary:
		return {"error": "Malformed snapshot JSON"}
	var envelope: Dictionary = json.data
	var spec := {"header": {"schema": "int", "content": "str", "build": "str", "campaign_id": "str", "sequence": "int", "rng_algorithm": "str"}, "payload": "str", "checksum": "str"}
	# Payload is intentionally allowed to exceed ordinary field-string limits.
	if not envelope.has("payload") or not envelope.payload is String:
		return {"error": "Invalid snapshot envelope"}
	var payload: String = envelope.payload
	var small := envelope.duplicate()
	small.payload = ""
	if not StateCodec.shape(small, spec):
		return {"error": "Invalid snapshot header"}
	var header: Dictionary = envelope.header
	if digest(header, payload) != envelope.checksum:
		return {"error": "Snapshot checksum mismatch"}
	var expected_schema := 3 if material_slot else (2 if exploration_slot else SCHEMA)
	var expected_content := "white-sedge-materials-1" if material_slot else ("white-sedge-1" if exploration_slot else CONTENT)
	if int(header.schema) != expected_schema or header.content != expected_content or header.rng_algorithm != "sha256-keyed-v1":
		return {"error": "Unsupported snapshot schema/content/RNG; migration required", "incompatible": true}
	if header.campaign_id != campaign_id or int(header.sequence) < 1:
		return {"error": "Snapshot identity/sequence mismatch"}
	if json.parse(payload) != OK:
		return {"error": "Malformed payload"}
	var state := StateCodec.decode(json.data)
	if state == null or state.campaign_id != campaign_id or state.exploration.is_empty() == exploration_slot:
		return {"error": "Snapshot state invariant violation"}
	if state.materials.is_empty() == material_slot:
		return {"error": "Snapshot material family mismatch"}
	return {"error": "", "state": state, "sequence": int(header.sequence), "source": source}

func write_file(file_path: String, source: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open snapshot for writing: " + str(FileAccess.get_open_error())
		return false
	file.store_string(source)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "Snapshot write/flush failed: " + str(error)
		return false
	return true

func replace_file(source: String, destination: String) -> bool:
	var error := DirAccess.rename_absolute(source, destination)
	if error != OK:
		last_error = "Snapshot replace failed: " + str(error)
		return false
	return true

func load_current() -> Dictionary:
	if directory.is_empty():
		return {"error": "Invalid campaign slot ID"}
	var current := read_file(path("current.json"))
	if current.error == "":
		sequence = current.sequence
		current.recovered = false
		return current
	if current.get("incompatible", false):
		return current # Never silently rewind an unsupported newer save.
	var backup := read_file(path("previous.json"))
	if backup.error != "":
		return {"error": "No valid continuation; current: %s; previous: %s" % [current.error, backup.error]}
	# Repair current without rotating the good backup over a corrupt primary.
	if not write_file(path("recovery.tmp"), backup.source) or read_file(path("recovery.tmp")).error != "" or not replace_file(path("recovery.tmp"), path("current.json")):
		return {"error": "Recovery found a valid backup but could not repair current: " + last_error}
	sequence = backup.sequence
	backup.recovered = true
	return backup

func save(state: CampaignState) -> bool:
	last_error = ""
	if directory.is_empty() or state.campaign_id != campaign_id or not StateCodec.problems(state).is_empty():
		last_error = "Invalid campaign slot or state"
		return false
	var ancestor := directory
	while not ancestor.is_empty() and not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor):
			last_error = "Campaign directory is blocked by a file"
			return false
		var parent := ancestor.get_base_dir()
		if parent == ancestor:
			break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Cannot create campaign directory"
		return false
	var current := read_file(path("current.json"))
	if current.error != "missing" and current.error != "":
		last_error = "Load/recover the existing continuation before writing: " + current.error
		return false
	# A crash/error after replacement may leave a committed write without its ACK.
	# Retrying that exact snapshot acknowledges it, rather than trapping the session.
	if current.error == "" and int(current.sequence) == sequence + 1 and current.state.fingerprint() == state.fingerprint():
		sequence = int(current.sequence)
		return true
	if current.error == "" and (int(current.sequence) != sequence or current.state.revision > state.revision or (current.state.revision == state.revision and current.state.fingerprint() != state.fingerprint())):
		last_error = "Stale writer or conflicting state revision"
		return false
	if current.error == "missing" and FileAccess.file_exists(path("previous.json")):
		last_error = "Recover the existing backup before writing"
		return false
	var next_sequence := sequence + 1
	var source := pack(state, next_sequence)
	if source.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "Snapshot too large"
		return false
	if fault("before_write"):
		return false
	if fail_at == "partial_write" or crash_at == "partial_write":
		write_file(path("writing.tmp"), source.left(source.length() / 2))
		fault("partial_write")
		return false
	if not write_file(path("writing.tmp"), source) or fault("after_flush"):
		return false
	var temporary := read_file(path("writing.tmp"))
	if temporary.error != "":
		last_error = "Temporary snapshot failed verification: " + temporary.error
		return false
	if fault("after_verify"):
		return false
	if current.error == "":
		if fail_at == "partial_backup" or crash_at == "partial_backup":
			write_file(path("previous.tmp"), current.source.left(current.source.length() / 2))
			fault("partial_backup")
			return false
		if not write_file(path("previous.tmp"), current.source) or fault("after_backup_write"):
			return false
		if read_file(path("previous.tmp")).error != "" or not replace_file(path("previous.tmp"), path("previous.json")):
			last_error = "Backup verification/replacement failed"
			return false
	if fault("after_backup_replace"):
		return false
	if not replace_file(path("writing.tmp"), path("current.json")):
		return false
	if fault("after_main_replace"):
		return false
	var verified := read_file(path("current.json"))
	if verified.error != "" or verified.sequence != next_sequence:
		last_error = "Final snapshot failed verification"
		return false
	sequence = next_sequence
	return true
