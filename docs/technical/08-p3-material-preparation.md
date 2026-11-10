# P3 / VS-03 · Material preparation

**Branch:** `work/p3-material-preparation`. **Base:** accepted P2 merge `ecdd3be645f34bd61a8953d479623af2e675580d`. Development and verification use the pinned Windows 11 toolchain. GDD 0.14.1 remains unchanged. This document records a runtime prototype, not calibrated balance.

## Play and review

From the repository root in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/p3.ps1 -Task Demo
```

The command prepares the pinned tools if absent, imports the project, and opens the existing White Sedge 3D scene with P3 enabled. Repeating it continues the same campaign. For a separate route use `-Campaign intact-root` or another name. This creates a distinct campaign, not an earlier save of the current one. After export, the equivalent standalone command is `& ./.artifacts/windows/CultivationRPG.exe -- --p3`.

WASD moves; Shift runs; E interacts with the nearest named object. Right mouse drag / arrow keys turn the camera; the wheel adjusts distance. J opens the dated journal; Esc opens the menu or dismisses a panel. Panels scroll vertically, including their choices. The opening help and menu contain the P3 route. All significant decisions save automatically; both the menu and normal window close save before exit.

### Short route: damaged root and workshop

1. At the red awning buy the collection kit (4), sealed vessel (6), and treatise (12). The starting wallet contains 80 spirit stones once. The sign episode is still available through the shop's conversation option; it is optional for P3.
2. Find Shen Yu by the green awning. Confirm herbalism tuition (8 stones / 4 years), then alchemy and both preparation methods from the treatise (6 years). Each action offers one-day advancement, completion of the remaining work, and save-and-exit. Reading or buying the book alone grants no mastery. The date is now year 10; no cultivation stage has been granted.
3. Walk northeast to the pale flowers beside the marsh. Inspect the physical trace, return to the interaction, and perform spiritual examination. Choose careful separation into two usable parts, acknowledging the loss of the living circuit. Alternatively, an attempt at whole extraction has a saved, operation-keyed intact/damaged outcome. The fixed normal profile currently yields an intact root for that choice; the damaged outcome is also tested with a controlled seed.
4. Follow the path west toward the pale mineral outcrop, before the watermill. Observe, then recognize the quartz. Extract at least one clean outer fragment for the smooth route (two for condensation). There are six total; the internal monolith is unavailable. No fight is required.
5. Return to the green awning. Under processing, order stabilization of one root part: 3 stones, 30 days, workshop custody, one stabilized intermediate. Review the terms before confirming. In Esc → property/processes, confirm 30 days of cultivation. Advance ten days, save and exit, and restart if desired. Complete the remaining twenty days. Visit the workshop, open processes, and collect once.
6. Select autonomous maturation of that intermediate: 30 days with your kit and vessel occupied. Cultivate for the same 30 days, then collect the stabilizer. At the workshop, compare methods and choose smooth preparation. One stabilizer and one quartz fragment become reserved, together with a budget of 8 stones (4 process + 4 future chamber). Wallet: 47 total / 39 free. The other root part and unspent materials remain real items.

For the self-processing route, replace the order with careful stabilization (2 active days), then the same maturation. Hurried heating (1 day) creates a known unstable intermediate; repair takes 1 stone / 3 active days. It is a useful defect with a repair route, not an unexplained random destruction. Division of an intact root (1 active day) irreversibly produces two parts. Quartz from rough opening requires cleaning (1 active day); its reduced energy is not restored.

### Intact route and alternative supply

In a separate campaign, attempt whole extraction and collect two clean, energy-retaining quartz fragments. Select condensation preparation: a whole living root (or one purchased condensation pill), two suitable fragments, and a budget of 12 stones (8 process + 4 chamber). Damaged parts cannot replace the living circuit. No extra Foundation strength is promised.

The comparison explains the GDD's later process: smooth preparation supports a five-year transition with possible reserve use / extra years / termination; condensation targets two years or three with alignment, with greater bodily risk. P3 reserves a material plan and future budget. It does **not** charge a chamber, execute either breakthrough, consume staged breakthrough payments, grant Qi perfection, or extend either life limit. Those conditions and decisions remain P5. Releasing or changing the plan frees its reservations; an invalid replacement leaves the previous plan intact.

Lo Wei's offers disappear with his death. Yin Qiu's explicit year-24 shipment provides two stabilizer doses and one condensation pill. Reopening, scene visits, elapsed time without a defined supply, and loading never refill either stock. Tools and the vessel are intentionally not reissued by the successor in this profile. Selling transfers a real item out of player custody; there is no free repurchase or fabricated material loop.

## Runtime profile and assumptions

[Runtime content](../../game/content/p3.json) is an explicit transcription of the relevant SLICE-02–05 cards, not a runtime import of `examples/`. It retains the P2 character, geography, travel and sign story. The P2 starting body is 18; this is a P3 extension of that playable profile, **not** a claim to reproduce the complete VS-DEBUG-01 / Lian Shen campaign timetable. The campaign still starts at world year 0, soul age 0, with a 100-year soul limit.

| Setting | Prototype hypothesis / scope |
|---|---|
| Starting means | 80 stones, kit 4, vessel 6, treatise 12; herbalism 8 / 4 years, alchemy from treatise / 6 years |
| Source quantities | One approximately 600-year-origin Glass Root; two parts if damaged/separated; six outer quartz fragments; no regrowth |
| Craft work | Divide 1 day; stabilize 2; hurried heat 1; repair 3 + 1 stone; clean quartz 1 |
| Autonomous / service | Maturation 30 days; workshop stabilization 30 days / 3 stones; one input and one intermediate output |
| Equipment | Sealed vessel holds eight material units. Kit and vessel are reusable, exclusive equipment for personal work and maturation. Workshop uses its own equipment |
| Storage | The sealed vessel preserves ordinary profile materials during its supported campaign horizon. Unstable essence loses usability 365 days after creation; previews disclose this. No wall-clock decay |
| Weight | 6.5 kg nominal carrying threshold; overload multiplies movement speed by 0.55. Six quartz fragments plus both parts and equipment weigh 7.9 kg |
| Ground storage | Leave and retrieve the same vessel with its contents at the green awning. It stays visible in the scene and unavailable remotely. Reserved property cannot be deposited |
| Mentor / workshop | Shen Yu has an authored mortality event (year 60, not disclosed by UI). Personal training stops with its actual progress and sunk payment. The institutional workshop continues across staff succession under its displayed terms |
| Cancellation | Active personal work has no safe cancellation; save/exit preserves it. Autonomous / workshop work returns raw input before any progress; after progress it returns unstable essence. Fees are not refunded; no output is issued |
| Mastery | Education gives operation knowledge; successful personal stabilization marks bounded mastery. Repetition never awards unbounded numerical growth; workshop service does not teach the recipe |

These are reversible engineering/content choices under OPEN-01/07/08/10/12 and the craft catalog/balance OPEN items. No accepted gameplay rule is changed. Wards, medicine, combat, full proficiency trees, production economics, late-stage crafting and reincarnation property resolution are outside P3.

## Architecture and save contract

`MaterialWorld` owns the P3 commands and invariants. `P3Content` loads the small authored JSON profile; `MaterialPanel` renders the UI and calls `SedgeSession.material`. The scene projects source depletion, physical storage and carrying burden. Existing `CampaignSession`, `Simulation`, `WorldCalendar`, `StateCodec` and `SnapshotStore` remain the command / calendar / persistence spine. No frame-driven calendar, runtime generation or additional service is introduced.

Each material has one stable identity, origin, approximate origin age, current integrity/purity/energy, owner, location, container, reservation and parent material references. Consumed input remains only as provenance; it is never a usable item alongside its output. Source quantities, purchased quantities, sale earnings, operation expenses, process inputs/outputs, container locations/capacity and preparation reservations are validated together. P1's historical supply counter remains separate from P3's spirit-stone wallet; there is no conversion or replenishment between them.

Personal learning and crafting use the existing action executor. Work stops at the next actual calendar/event/life boundary. A paused personal action prevents another occupation; resume continues the same progress and costs. Autonomous and workshop deadlines are additional boundaries on the **same** calendar. A 30-day order and 30-day cultivation over that interval consume thirty days, not sixty. Readiness occurs without a scene visit; workshop knowledge requires a visit. Issuance is a separate saved transition. Walking, reading, menus and time outside the application do not advance work.

All commands mutate a candidate, check invariants, and checkpoint through the current/previous atomic snapshot protocol before further commands. Failed writes leave the candidate dirty and require exact retry. The original eight crash boundaries remain unchanged. No gameplay backup-selection UI is added.

P3 uses **schema 3 / `white-sedge-materials-1`**, under `user://sedge-materials/<campaign>`. P1 schema 1 and P2 schema 2 remain supported by their existing entry points and slot families. P3 deliberately starts a new campaign on the expanded profile; **there is no P2-to-P3 migration**. It refuses to read or overwrite an older schema in place, and tests preserve the old file byte for byte. This avoids silently granting stock, tools or an initial wallet to an already progressed P2 campaign. Unsupported newer/current saves still prevent fallback to an earlier supported backup.

## Reproducible verification

```powershell
pwsh -NoProfile -File tools/p3.ps1 -Task Verify
pwsh -NoProfile -File tools/verify_clean_checkout.ps1 -Phase P3
python tools/validate_design.py
```

`Test` runs import and the P3 domain suite. `Crash` runs actual hard terminations of writers, not graceful quits or only injected return values. `Verify` includes full P0–P2 verification, release Windows export, P3 rules, crash checks, graphical project/export continuations and both preparation routes. `Smoke` requires an up-to-date export. The clean-checkout script clones committed HEAD into a path containing spaces, rechecks cached archive hashes, freshly extracts tools, imports and exports without copying `.godot` or installed binaries, runs the same verification, and requires a clean Git tree.

After a successful clean run, `python tools/record_p3_validation.py --checkout "<clean checkout path>" --clean-log .artifacts/p3-clean-checkout-final.log` verifies the required logs, crash confirmations, PE architecture and unchanged runtime files. It writes the portable validation record, copies selected original frames and creates local `.artifacts/p3-review-evidence.zip` with sanitized logs and frames. It records results and never substitutes for running the checks.

The graphical probe drives the normal menu callbacks, checks nearby interaction targets, actual movement, source visuals, panel scroll reset and saved state. The first project process exits ten days into cultivation while a paid order is pending. A separately launched Windows export resumes it, completes the order, collects, matures the intermediate in parallel, and saves the smooth plan. Another exported route prepares condensation from an intact root. The property route compares actual movement under load, leaves the vessel in the world and retrieves its unchanged contents. A late-calendar route checks the immediate visible replacement of both mortal NPCs and collection from the surviving workshop. This is automated application testing with inspected frames, not an independent human usability playtest.

A normal, non-smoke launch was also controlled through the Windows UI: mouse scrolling reached the lower help choices, clicking the method comparison opened it at its beginning, and normal window close saved successfully. A second launch continued the same named campaign; its final orderly close advanced snapshot sequence 2 to 3 while day 0 and wallet 80 remained unchanged. This checks ordinary input and closing, not an owner's acceptance of the complete route.

| GDD acceptance | P3 coverage and boundary |
|---|---|
| AT-RES-01–05 | Evidence → recognition → qualified extraction; risky intact and damaged outcomes; origin/state distinction; fixed source depletion; storage warning and calendar expiry |
| AT-SAVE-01–03, AT-SAVE-04/07 | Exact round trips, mid-lesson / mid-repair / interrupted work, partial depletion, payment/collection/reservation, separate campaign families, failed-write retry and actual process-crash recovery |
| AT-CRAFT-01/02 | Book versus learned knowledge, bounded practice; new-body execution requirements remain P5 |
| AT-CRAFT-03–08/11 | One-confirmation routines, limited recipe potential, correctable defect, exclusive equipment, common-calendar work, partitioned waiting, disclosed order terms and familiar results |
| AT-CRAFT-09/10 | Mortal personal teacher versus institutional workshop; readiness while travelling, return and one-time collection. New-body rights remain P5 |
| AT-WORLD-02 | Depleted sources, finite old/new stock and source identity persist independently of scene recreation |
| AT-PROPERTY-01 | Weight affects actual movement; deposited container and contents remain physical and unavailable remotely. Spatial artifacts / Qi preparation remain later systems |
| AT-TIME / AT-SOUL / AT-STORY regression | Existing P0–P2 suites retain their earlier coverage; P3 adds no new life-limit grants or combat claims |

## Verification result and P4 handoff

On 11 November 2026, executable source **`2da941960e18eabb20b9686e14a50753e1cc70db`** passed `P3_CLEAN_CHECKOUT_PASS` on Windows 11 / AMD RX 580 2048SP. The clean clone freshly extracted the verified pinned tools, rebuilt the Blender probe, imported, ran all phases, exported Windows x86-64 and finished with an empty Git status. Subsequent changes add only documentation and the evidence-recording helper; its comparison confirms all **107 tracked runtime files** remain byte-identical to the tested source.

| Actual check | Result |
|---|---|
| P0 | Source-to-GLB rebuild, import / asset contract / animated startup, Windows release export and both renderers passed |
| P1 regression | 182 assertions; all 8 actual terminated writers recovered; laboratory and project/export launches passed |
| P2 regression | Asset membership/hashes, 47 assertions, interrupted ferry continuation, story / key / grate traversal and both renderers passed |
| P3 domain | **311 assertions**, including split waiting, stock/economy conservation, storage, interrupted learning, active repair, mortal teacher, institutional orders, origin/quality, both material plans and incompatible-schema byte preservation |
| P3 process crashes | **64 hard terminations and successful continuations**: purchase, extraction, order, active completion, autonomous completion, collection, method choice and sale at all 8 protocol boundaries |
| P3 Windows application | Project → independent export continuation, standalone export two-launch route, intact-root condensation, actual load/storage traversal and visible mortality/succession passed in Forward+ and Compatibility |
| Build identity | PE machine **0x8664**; executable and PCK SHA-256 recorded; original-frame hashes and 41 check logs recorded |
| Documentation | GDD / reference validator passed with zero errors, separately from execution |

The [portable validation record](evidence/p3-validation.json) contains the tested revision, log/asset/build/frame hashes, all 64 crash confirmations and reproduction commands. Selected original frames show [extraction](evidence/p3-root-forward_plus.png), [order terms](evidence/p3-contract-forward_plus.png), [smooth preparation](evidence/p3-prepared-forward_plus.png), [condensation preparation](evidence/p3-condensation-forward_plus.png) and [Compatibility preparation](evidence/p3-prepared-gl_compatibility.png). The local `.artifacts/p3-review-evidence.zip` holds sanitized full logs and selected frames; binaries remain reproducible local build output. The owner has not yet independently accepted P3.

**P3 is ready for independent review. P4 can proceed after acceptance.** All eight requested P3 criteria are covered within this documented prototype scope; full breakthrough execution is deliberately outside this stage.

P4 should add its single combat implementation and technical flight / dynamic recovery probes against this same campaign architecture. P3's reserved material plan is an input to later P5 integration, not an implemented breakthrough. No P3 result establishes combat balance, production balance, a second-machine result, dense-scene performance, power-loss durability or independent owner acceptance.
