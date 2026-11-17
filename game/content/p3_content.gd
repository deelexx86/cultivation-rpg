class_name P3Content
extends RefCounted
## Explicit runtime transcription of SLICE-02–05, with P3-only hypotheses.
static var cached: Dictionary = {}

static func data() -> Dictionary:
	if cached.is_empty():
		cached = integers(JSON.parse_string(FileAccess.get_file_as_string("res://content/p3.json")))
	return cached

static func integers(value: Variant) -> Variant:
	if value is float: return int(value)
	if value is Dictionary:
		for key: String in value: value[key] = integers(value[key])
	if value is Array:
		for i in value.size(): value[i] = integers(value[i])
	return value
