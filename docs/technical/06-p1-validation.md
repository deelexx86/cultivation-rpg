# P1 / VS-01 validation and handoff

**Date:** 2026-11-10. **Branch:** `work/p1-core-time-state`. **Base:** `bb62c4c` (`origin/master`, including merged P0). The initial working tree was clean; no unrelated changes were present. `master` is unchanged. No PR merge or deployment is part of this task.

## Result and engineering decisions

The executable P1 kernel provides typed, scene-independent campaign/soul/body state; a day-accurate Gregorian calendar; preview/confirmation, paid actions and interruption/resumption; causal world-event processing; first/repeated milestones and life expiry; versioned snapshots, recovery and an interactive diagnostic scenario. The P0 asset and main technical probe remain available unchanged in purpose.

The [P1 contract](05-p1-core-contract.md) records the exact implementation of OPEN-01 and the P1 part of OPEN-10, alternatives and limitations. Saturday day 0 and February-28 clamping complete the calendar convention. Explicit dependency edges avoid using arbitrary IDs to decide dependent same-day outcomes. A verified JSON snapshot plus one previous valid snapshot was chosen over a journal or full event sourcing, keeping the first kernel inspectable and small. Synchronous writes avoid introducing an asynchronous snapshot queue. No dependencies or global configuration changes were added; the pinned Godot/Blender toolchain is unchanged.

Affected accepted rules are TIME-01–15, TIME-17, TIME-22–24, TIME-28, TIME-SAVE; STATE-01–06, STATE-08–12; SPACE-02–04, SPACE-07–10; and the soul/body ownership part of CHAR-01. These are implemented within the P1 probe boundary, **not changed**. Numeric milestone limits, durations and costs remain controlled test data. The full breakthrough, character, inventory, route, crafting and reincarnation systems are not implemented.

## Environment

Same available Windows 11 machine and pinned tools as [P0](04-p0-validation.md): Ryzen 5 5600, 64 GiB class RAM, AMD RX 580 2048SP, driver 31.0.21925.1001, Godot 4.8.beta3.official.c51ff06e8 Standard, matching Windows x86-64 templates, Blender 5.2.3 LTS, PowerShell 7.6.9, Python 3.14.0 and Git 2.56.0.windows.4. Forward+ uses Vulkan 1.3.260; Compatibility uses the available OpenGL 3.3 driver. This is one physical machine, not a second-machine or minimum-hardware validation.

## Automated acceptance coverage

`game/tests/p1_tests.gd` currently passes **182 assertions** in six groups. The calendar group additionally checks **292,195 individual day conversions**, covering two full 400-year Gregorian cycles and day 0. Group success text is diagnostic; overall success requires zero failures, zero engine/script errors and `P1_TEST_PASS`. The process runner rejects errors even when Godot exits with code zero.

| GDD scenarios | Executed P1 evidence | Scope still outside P1 |
|---|---|---|
| AT-TIME-01, 07 | Repeated previews preserve full state, dates, supplies, knowledge and random fixture data; preview hides the NPC's exact death event; stale/changed forecasts and duplicate confirmation tested | Local exploration, battle, gathering and their UI do not yet exist |
| AT-TIME-02, 03 | Soul and body tested separately: completion one day before expiry succeeds, same-day/one-day-later rewards fail; forecast agrees; expiry is saved | Actual breakthrough preparation/trial and animations |
| AT-TIME-04 | Practice from year 4 to 24 resolves NPC death and personal obligation at year 15; absence of communication does not expose hidden knowledge | Full quest delivery and physical quest item |
| AT-TIME-05 | One 20-year wait vs four five-year actions, with reloads, gives identical world event history, state and keyed outcome | Resource/merchant/cache systems beyond small saved flags |
| AT-TIME-06 | Practice 312→346, eight-year recovery to 354, remaining practice to 410; 98 elapsed years, correct retained progress and two paid starts | Production cultivation/recovery methods and balance |
| AT-TIME-07; AT-SAVE-08 | Preview is pure; stale conditions rechecked; known expiry requires separate confirmation, cancellation spends nothing | Unknown breakthrough risk model and complete gameplay knowledge projection |
| AT-SOUL-01, 02 | Prepared soul at 445 with limit 1030, body age 18; former peak restored at 585 without soul extension; first higher milestone at 695 sets 1160; receipts and reload preserve the result | Production stage catalog and playable body transition |
| AT-SOUL-03 | No-body calendar probe with three years remaining and five-year requested duration ends at soul expiry, without creating a body | Full transfer process/selection |
| AT-SOUL-04–06 | Body-history fixture retains soul mastery (including partial mastery), world flags and independent body progress; expiry adds no bonus or reset; prepared two-body state survives load | Physical item fate, compatibility/attributes, playable death-to-rebirth loop; these full scenarios are not claimed passed |
| AT-SAVE-01, 03 | Repeated exact loads, persisted receipts/outcomes, partial paid practice, unresolved interruption and single completion | Full extraction, breakthrough failure, cache and quest reward examples |
| AT-SAVE-04, 06 | Separate slots; no offline date advancement; immediate expiry checkpoints and reload; demo exit saves before close | Purchase/dialogue, dynamic world movement, playable transfer and campaign-list/results UI |
| AT-SAVE-07 | Eight injected failure points plus eight actual writer-process terminations; primary corruption, missing primary, bad backup, both files bad, retry, checksum/schema/invariant failures and stale writer rejection | Hardware power loss and unsupported future migrations |
| AT-SPACE-01 | Month/year transitions, year 0/100/400 leap rules, signed birth dates, anniversaries, seven-day week and exhaustive conversion | None for the implemented P1 calendar convention |
| AT-SPACE-02, 03 | Data-only route probe stops on day 4 of 10, preserves encounter result/cost/progress, reloads and completes the remaining six days once | Playable travel, route modifiers/sections and combat encounter scene |
| AT-SPACE-04, 05 | Data-only B-region consequence advances on the one global date without visiting B; reversed event storage order and split time give identical causal history | Region scene loading/streaming and gameplay content |
| AT-SPACE-06 | Treating a cause cancels its scheduled death and dependent market/communication events; destroyed bridge cannot receive an obsolete repair; already-dead NPC cannot die again | Story/dialogue intervention UI |

Additional tests cover a last-day interruption followed by zero-day completion, paid recovery while practice is paused, cyclic/missing dependencies, ambiguous same-day writes, multiple interruption channels on one date, invalid numeric data and dangling participants. P1 rejects multiple same-date interruption channels explicitly rather than silently masking a choice; several consequences can feed one authored channel. A valid checksum over an invalid state does not bypass invariant validation. These are rule tests and controlled fixtures; no playtest or validated balance is inferred.

AT-SAVE-02 (production item conservation), AT-SAVE-05 (dynamic combat), AT-SOUL-07 (playable awakening), resource/profession tests and VISION-09 remain unimplemented later-stage work. They are not counted as completed P1 scenarios.

## Crash/recovery evidence

`tools/verify_p1_crashes.py` launches the real engine executable, not its Windows console relay. Each writer first commits a practice start and day-5 partial checkpoint, then attempts day 10. The harness waits for the target protocol marker and force-terminates that writer process. A fresh engine loads and continues the action to day 20, checking progress, 19 supplies remaining and exactly one supply spent.

| Termination point | Recovered day |
|---|---|
| Before opening the temporary file | 5 |
| Half-written temporary payload | 5 |
| Temporary flushed/closed | 5 |
| Temporary validated | 5 |
| Half-written backup temporary | 5 |
| Backup temporary flushed/closed | 5 |
| Backup replaced, primary not yet replaced | 5 |
| Primary replaced, before success acknowledgment | 10 |

The same eight stages are tested as ordinary reported I/O failures, retaining memory and retrying without duplicate costs. A real directory-creation obstruction is also tested. This is evidence of application-crash recovery on the tested filesystem, not proof of power-cut durability. Temporary files are ignored as continuations. A valid unsupported future schema is refused without silently rolling back to a backup.

## Commands, runtime and evidence files

The commands are in the [contract](05-p1-core-contract.md) and [Windows workflow](03-windows-development.md). The final full verification must be rerun after any executable change. Local generated logs, exports, crash snapshots and screenshots are in ignored `.artifacts/`. The committed evidence summary will identify the final successful logs and source revision; it does not replace rerunning the checks.

Observed during development: `P1_TEST_PASS`, `P1_CRASH_PASS stages=8`, and the demonstration reaches `0020-01-01`, progress 7305 days, one supply spent after interruption/load/resume. P0 asset rebuild, import, typed asset tests, headless startup, design validation, Windows export and real project/export startup passed in the integrated run. P1 also executed through the independent exported release and both renderers. The final evidence summary records the exact final assertion count/source revision.

Visual inspection found missing glyphs on the available AMD driver despite passing runtime assertions. Size-only and ASCII-precache experiments did not fix both paths. The diagnostic theme uses 24-pixel bitmap glyphs for Forward+ and the existing MSDF fallback for Compatibility; the smoke scenario gives each visible callback time to render. Final project/export screenshots are inspected separately. This is a local diagnostic workaround, without changing P0's global font setting or the pinned renderer/toolchain. The output history scrolls. These labels are development diagnostics in English; the accepted gameplay prototype language is unchanged.

One initial import using the old P0 `.godot` cache stalled before registering new classes. The task-owned process was stopped and that generated cache was moved into ignored artifacts, preserving source. Fresh import succeeded. The process timeout wrapper now terminates Godot's Windows process tree so a stalled console relay cannot leave its engine running; a deliberately timed-out Python parent/child probe confirmed both termination and the failure exit (`P1_TIMEOUT_TREE_PASS`). Clean-checkout verification must prove the committed implementation without reusing that cache.

## Clean checkout and publication

Pending final committed-source verification and branch publication. This paragraph must be replaced with the actual result before completion. The check creates a fresh clone in a path containing spaces, copies only verified download archives, freshly extracts tools, imports, tests, exports and runs both real renderers. Git must remain clean. No engine cache, installed tool binary or earlier export is copied.

## Readiness for P2 / VS-02

The tested kernel is a suitable **technical** base for P2 once final clean-checkout verification is green. It has demonstrated the difficult time/state/save boundaries rather than only JSON serialization. It does not make the larger game, content schema or 3D performance ready.

P2 should connect its small third-person scene and interactions to `CampaignSession`, keep scene lifetimes separate from persistent records, introduce dated knowledge/resource/route definitions, and exercise the first small dialogue consequence through this snapshot boundary. It must extend schema 1 deliberately for new state, test compatibility/migration policy, and choose measured persistence points/cadence for movement. The actual route encounter and the Lo Wei narrative remain P2 work. Body creation/transfer remains P5; dynamic combat restoration remains a P4 gate before combat expansion. VISION-09, machine B and physical second-machine transfer remain future checks.
