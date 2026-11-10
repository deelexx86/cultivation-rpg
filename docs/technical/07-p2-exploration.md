# P2 / VS-02 · White Sedge

## Playing on Windows

From the repository root on the published branch, run `pwsh -File tools/p2.ps1 -Task Demo`. The first launch prepares the pinned toolchain if needed and imports the committed GLBs. Subsequent launches open the current White Sedge campaign. For an already built Windows release run `& '.\.artifacts\windows\CultivationRPG.exe' -- --p2`. The foundation scene also supports the historical P0 and P1 verification entry points.

Move with WASD, hold Shift to run, and press E when the bottom prompt names the object. Turn with the left/right arrows or hold the right mouse button and drag to orbit and tilt. The wheel adjusts camera distance. Read the journal with J. Esc opens the menu or dismisses a conversation. The menu and window close both support saving before exit.

1. Find Lo Wei beside the red awning and choose whether to help. Follow the stepping stones toward the wheel. Pick up the glint in the mud and return to the merchant. His promised supply and custody of the sign are saved together.
2. Inspect the pale flowers at the margin of the marsh. Examine the physical sign, then interpret it and assess your ability to extract the root. The journal keeps the dated observations. The starting character lacks the relevant herbalism mastery.
3. At the boat and lantern east of the court, inspect the forecast and confirm the crossing. After two days the ferryman needs help with the rope. Use the encounter's save-and-exit button, restart, resolve it, and complete the remaining three days. Return by the same ferry to see the changed shore, revisit the root and speak to Lo Wei again.
4. Accept the sign at the later meeting, compare its notch to the old grate, and fit the physical key. Walk through the opening. For the late branch, use the cart at the far landing to confirm a sixteen-year practice before returning. Yin Qiu cannot settle Lo Wei's promise. The sign remains wherever it was when Lo Wei died. A sign still available to the hero can also be examined independently and installed without his account.

Each named campaign has one continuation. To play a separate branch, run `pwsh -File tools/p2.ps1 -Task Demo -Campaign late-return`. Reuse that name to continue it. Automated tests use isolated slots.

## Campaign and scene

`SedgeWorld` supplies the authored opening and domain commands. `SedgeSession` clones, validates and commits through the P1 campaign session. The scene projects the authoritative holder, living merchant, source, gate and landing. Player transform and camera motion are presentation state between checkpoints. The seed for background dressing is constant per location and has no gameplay effects.

The prototype binds a single instance, `lo-wei.copper-seal.01`, to one custody field. Its possible locations are the spillway, the player's body, Lo Wei's possessions, and the grate socket. Returning the sign closes the personal obligation and pays once. His death on the year-15 boundary closes an outstanding promise and preserves possession. A gift requires a later calendar day and living Lo Wei. A socketed sign stays in the grate. Notes record the observation or speaker in the operation key and the date in its value. Flooding preserves older observations; a subsequent inspection can establish that they are out of date.

Travel uses the P1 calendar executor with a playable travel action. Confirming the forecast saves departure and the encounter definition together. The first crossing stops on its second actual day. Resolving it commits the rope consequence, the changed water level and the resumed action together. Completion and arrival coordinates share one snapshot. Both landings load the complete small scene. Local walking, dialogue, inspection and journal access spend zero days.

Schema 2 with content identity `white-sedge-1` uses a separate slot family under `user://sedge`. The schema-1 P1 diagnostic remains playable from its original slot. An attempt to open or overwrite that slot with P2 is rejected and tested for byte preservation. Centimetre-rounded horizontal coordinates are persisted after movement every five seconds, before opening a world interaction, at arrival and on orderly exit. Stationary periodic checks skip disk writes. Height is reconstructed on the authored walkable ground. Checkpoints use the P1 current/previous recovery protocol. A hard interruption may lose up to one movement interval. Camera orbit and zoom are session settings.

## Art and production decisions

The [asset register](../../art/sedge-assets.json) records three Kenney releases, original archive SHA-256 values, exact runtime files and their hashes. The pack-specific CC0 notices accompany the files. The repository ships 20 GLBs and two referenced palette textures. The selected models can be imported directly without Blender or the source archives. Blender remains part of the P0 regression.

Kenney's matching silhouettes, small GLBs and shared character animations fit the walking slice. Poly Haven's CC0 catalog was also considered. The chosen direction uses paired open trading awnings, a tiered sluice roof, a reed bank and distant stone peaks. The roofs, stall furniture, plants, rock formations and three character rigs come from the packs. Simple authored geometry supplies ground, water, wear paths, the unique sign, moving grate and collision proxies. The camera uses a spring arm. Locomotion blends idle, walk and sprint, with clip speed adjusted to actual horizontal movement against obstacles.

The five-day forecast, flood modifier, one-supply payment, travel stops and practice shortcut are prototype content. Lo Wei's death date and personal custody branches follow the accepted White Sedge episode. The demo covers recognition and qualification; extraction, crafting and trade remain P3 work. The generic characters retain the proportions of the source pack. Physical foot locking and bespoke age-specific character art remain production work.

## Reproducing checks

- `pwsh -File tools/p2.ps1 -Task Verify` runs the full P0/P1 verification, including actual writer terminations, Windows export and both renderers. It then verifies asset membership and hashes, P2 domain tests, and project/export traversal.
- `pwsh -File tools/verify_clean_checkout.ps1 -Phase P2` clones the committed branch, verifies and freshly unpacks the pinned tools, runs the same checks and requires a clean Git status.
- `python tools/validate_design.py` checks documentation and reference data separately.

The project and exported app share a disposable slot in the cross-process test. The first process saves and exits during the encounter. The second process continues it, returns, obtains the entrusted key and tests physical passage through the closed and opened grate. Other tests cover refusal, timely return, late discovery, independent deduction, death between return and gift, stale knowledge, duplicate rewards, migration refusal and exact snapshot round trips. These exercise the applicable portions of AT-TIME-01/04/07, AT-RES-01/04, AT-NPC-01/03, AT-SAVE-01/02/04/07, AT-WORLD-02, AT-SPACE-02/03 and AT-STORY-01. Resource extraction, transfer between bodies and combat portions of those families require their later gameplay systems.

## Verified result and P3 handoff

On 10 November 2026, executable source `7678c8a1289ce9472b62e5429bcd7f62875d576a` passed the full clean-checkout run on Windows 11 and an AMD RX 580 2048SP. It rebuilt the Blender P0 probe, imported the subset, passed P0 and 182 P1 assertions, recovered all eight terminated writers, passed the asset hash check and 47 P2 assertions, and launched the project and Windows x86-64 export in Forward+ and Compatibility. Both exported processes continued the project-created mid-crossing save and walked through the unlocked grate. A separate two-launch check of the one-command demo used normal window close on a named campaign and advanced its save sequence from 2 to 3 at day zero.

The [validation record](evidence/p2-validation.json) includes the tested revision, log hashes, executable and PCK hashes, PE architecture and original frame hashes. The [Forward+ frames](evidence/p2-forward_plus.jpg) and [Compatibility frames](evidence/p2-gl_compatibility.jpg) show the court, marsh, watermill entrance and Russian dialogue. Compatibility is visibly brighter and shows fine stippling on awnings. Both render paths preserve the wheel silhouette and readable dialogue.

P3 can use the existing source identity, independently dated observations and transaction boundary for its first extraction operation. It still needs to model yield, damage, storage and qualifications for that operation. Independent player comprehension, precise foot-contact measurements, production balance and performance on a second GPU remain unmeasured.
