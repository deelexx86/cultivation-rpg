# P1 / VS-01 simulation and persistence contract

**Version:** 1 · **Date:** 2026-11-10. Implementation supplement to technical package 0.2.1, within the owner's delegated P1 engineering scope. GDD remains 0.14.1; no accepted gameplay rule or balance value changes.

## Ownership and executable scope

`game/src/domain/` owns typed campaign, soul, body, action, person, obligation and event records, the calendar and simulation rules. It has no scene, filesystem or frame-clock dependency. `game/src/application/campaign_session.gd` clones a candidate, applies a command, validates it and publishes one coherent in-memory state. `game/src/infrastructure/` validates/encodes snapshots and writes them. Scenes send intentions and render state; they do not create rewards on reload.

The initial campaign starts at ordinal 0, soul age 0, soul limit 100 calendar years and a prepared 18-year-old body with a 100-year body limit. Ages derive from birth ordinals; deadlines derive from birth plus the current calendar-year limit. They are never separately incremented counters. Body history remains in the campaign. Prepared two-body tests exercise old-soul/young-body rules without implementing reincarnation.

`game/content/p1_fixture.gd` is a small authored **technical fixture**, independent of `examples/`. Its costs, dates, retained day-by-day practice and milestone limits are test inputs, not accepted production balance or a universal cultivation formula. It is not the White Sedge narrative. The `travel_probe` and `transfer_probe` action kinds exist only for controlled rule tests; there is no playable route or body-selection system. P2 must introduce its small validated authoring format and content definitions before narrative production.

## OPEN-01: P1 calendar policy

The accepted proleptic Gregorian calendar is implemented using astronomical year numbering. Day 0 is 0000-01-01; year 0 is leap. Weekdays use Monday = 0 and anchor day 0 to Saturday. This matches the backwards extension of the Gregorian calendar and gives a reproducible seven-day week without a timezone dependency.

Adding years keeps month/day and clamps February 29 to February 28 in a common target year. Life deadlines are always calculated from the **original birth date**, so a later leap-year anniversary returns to February 29. Sequentially adding one year to an already clamped ordinary date keeps that ordinary date; callers that mean a birth anniversary use the original birth. This avoids accumulating calendar drift. Negative ordinals are supported for initial adult birth dates; the conversion is exhaustively round-tripped over two full Gregorian cycles around year 0. Executable P1 campaigns are restricted to years 0–2999; endgame and the year-3000 ascension transition are outside this implementation.

At each boundary the executor:

1. Accumulates only the actual elapsed days of the current fixture action.
2. Resolves soul expiry and body expiry before any new life limit (TIME-08). Simultaneous soul/body expiry ends the campaign, rather than opening a transfer opportunity.
3. Resolves all world events of that date in topological causal order. Independent ties use stable event IDs.
4. Applies an interruption with its explicit information channel, or completes the still-valid action and its milestone once.
5. Saves the entire boundary before progressing farther.

Events have stable IDs, dates, kinds, targets, explicit prerequisites and live conditions. Missing references, backwards date edges, cycles and ambiguous same-day reads/writes are rejected before mutation. Dependencies must have been **applied**, not merely visited. Changes to a premise are retained immediately; cancellation is resolved on the affected event's actual scheduled day, and cancelled causes cancel their dependants. No stale future effect is applied. This small executor handles the fixed graph; it does not dynamically manufacture events or truncate a queue after an arbitrary count.

Death closes personal obligations at the actual death date. A later death cannot kill an already-dead NPC again. Background consequences do not add knowledge. Only an explicitly configured interrupting event adds its channel/date to known information. The debug screen labels resolved world facts as diagnostic information. P1 validates that at most one authored interruption channel exists per date, so multiple interruptions cannot silently mask each other. Multiple world consequences can lead to that one explicit choice; richer choice content belongs to P2.

## Actions and idempotency

Preview includes the current revision/fingerprint, duration, projected date/ages, current life boundary, supplies, known obligations and a risk statement. It neither mutates state nor resolves random outcomes. Confirmation recalculates the preview; stale or altered forecasts require a new preview. A forecast with known expiry before or on completion needs a separate fatal-outcome confirmation. The debug interface provides that confirmation and permits cancellation without spending anything.

Confirmation, resume and the test intervention command have operation IDs and persisted request receipts. Redelivery of the same ID/request is a no-op; changed reuse is rejected. Startup expense and action identity are one transaction. `advance(days)` is an internal execution budget, not a retryable new paid intention: repeated budget requests can deliberately progress an unfinished running action, while already resolved event/completion effects remain one-shot. In normal play the confirmed action defines the total remaining duration.

The executor moves to the nearest action end, event, expiry or requested budget boundary. Paused actions retain their paid cost and exact progress; a separate recovery action can use the calendar before resumption. A same-day interruption can leave all action days elapsed while completion remains unresolved; explicit continuation then completes it at zero additional days. A loaded running action does not advance until an explicit continue command. No idle frame or offline wall-clock time advances the campaign.

First milestone IDs and their first dates belong to the soul. A new personal milestone raises the soul limit using a maximum, never an additive grant. A repeated milestone can raise the body's limit without granting soul years again. Expiry prevents the completion reward. The fixture stores retained practice days in the body and mastery in the soul; it does not implement full character progression or breakthrough preparation/trial gameplay.

## Reproducibility

P1 has no random gameplay. An operation-keyed `sha256-keyed-v1` two-outcome fixture tests persistence and independence from wait partitioning and unrelated region data. Its seed string, algorithm ID and resolved event outcomes are saved. This is not a chosen gameplay probability distribution. No preview, scene visit, body death or cosmetic event requests another outcome. Future real random systems need their own versioned state/algorithm contract and schema changes.

## OPEN-10: P1 snapshot policy

The format is explicit UTF-8 JSON, schema 1, content `p1-fixture-1`, build `0.1.0-p1`. Each campaign has one `current.json` and one recovery-only `previous.json` below `user://campaigns/<validated-id>/`. Tests use isolated slots. Temporary files have no authority as a continuation. No backup selector exists in the interface.

The envelope contains schema/content/build/campaign/sequence/RNG metadata, a JSON payload string and SHA-256 over canonical metadata plus that exact string. Header numeric fields are normalized to integers before digesting because Godot parses JSON numbers as floats. Parsed integer fields must be finite, integral and within declared bounds. The codec checks exact record shapes, IDs/references, dates, lifetimes, action statuses, resource expense totals, event graph and campaign mode before constructing a usable continuation. There is a 16 MiB file limit. Checksums detect corruption; this is not an anti-editing or security mechanism.

Write protocol, all in the same campaign directory:

1. Check the writer's last loaded sequence and reject stale/conflicting state.
2. Write `writing.tmp`, flush, close and reload/validate it.
3. Copy the existing valid primary into `previous.tmp`, flush/close/validate, then replace `previous.json`.
4. Replace `current.json` with the verified temporary file and verify the result before reporting success.

The primary is never removed to create a rename gap. A failure while preparing the backup leaves the primary intact. A failure after primary replacement can produce an ambiguous successful write; retry recognizes the exact committed state and acknowledges its sequence. Synchronous session ownership avoids an asynchronous older snapshot replacing a newer one. Separate simultaneous application processes writing the **same slot** are not supported; the sequence check detects sequential stale writers but is not an interprocess lock.

Load prefers a valid primary. A missing/corrupt primary falls back to the previous validated snapshot and repairs the primary without rotating the corrupt file over the backup. A valid but unsupported newer schema/content/RNG fails explicitly instead of silently rewinding to an older backup. Two invalid files fail without resetting the campaign. Schema 1 is the first executable campaign schema: no migration from illustrative JSON or future schemas is promised. Future schema/content changes must declare compatibility or supply a tested migration.

Every mutating command and every calendar execution boundary saves synchronously, including partial progress, expiry, cancellation, interruption and completion. Exit saves before closing. Between those operations P1 has no changing simulation state, so a periodic wall-clock save timer adds no persistence coverage; a cadence for continuous movement is deferred to P2. A failed write retains the coherent in-memory state, displays the error and blocks further mutations/loading until Save / retry succeeds. The OS close request follows the same rule.

The [official FileAccess](https://docs.godotengine.org/en/latest/classes/class_fileaccess.html), [DirAccess](https://docs.godotengine.org/en/latest/classes/class_diraccess.html) and [JSON](https://docs.godotengine.org/en/latest/classes/class_json.html) contracts were consulted; the pinned beta executable is the actual API/runtime test. Eight real process-termination points, injected failures, corruption and recovery are exercised on Windows 11. This establishes the tested **application-crash** behavior. Hardware power loss, filesystem/controller failure, disk exhaustion during an actual device failure, concurrent writers and physical second-machine testing are not claimed proven. Flush/rename alone is not evidence of power-loss durability.

## Running and extending

From PowerShell 7 after the P0 setup:

```powershell
pwsh -NoProfile -File tools/p0.ps1 -Task Import
pwsh -NoProfile -File tools/p1.ps1 -Task Test
pwsh -NoProfile -File tools/p1.ps1 -Task Crash
pwsh -NoProfile -File tools/p1.ps1 -Task DemoSmoke
pwsh -NoProfile -File tools/p1.ps1 -Task Verify
pwsh -NoProfile -File tools/p1.ps1 -Task Demo
```

Interactive route: Preview 20 years → Confirm practice → Advance → observe year 9 / deceased NPC / ended promise → Load current → Acknowledge & resume → Advance → year 20 and one paid start. Closing/reopening continues the same `p1-demo` slot. Automated smoke creates an isolated new slot, exercises those same callbacks, verifies state and exits. The exported executable supports `-- --p1-demo`; without that argument it still runs the P0 probe.

`Verify` performs the full P0 asset/import/test/design/export/real-window regression, then P1 logic, process-crash tests, headless demo and real project/export demos with both Forward+ and Compatibility. After committing, run `pwsh -NoProfile -File tools/verify_clean_checkout.ps1 -Phase P1 -Branch work/p1-core-time-state`. This reconstructs tools from verified archives and tests committed source without copying engine caches or exports. Details and the acceptance boundary are in the [P1 validation report](06-p1-validation.md).
