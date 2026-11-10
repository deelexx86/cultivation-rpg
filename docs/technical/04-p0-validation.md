# P0 / VS-00 validation

**Date:** 2026-11-10. **Branch:** `work/p0-foundation`. **Base:** `be1cee2` on `origin/master`, after fetching and confirming the accepted technical package was already merged. The initial worktree was clean. `master` was not modified or merged by this task.

## Environment and decisions

| Item | Actual observation |
|---|---|
| OS | Windows 11 Home x86-64, 10.0.26200, build 26200 |
| CPU / memory | AMD Ryzen 5 5600, 6 cores; 68,641,923,072 bytes physical RAM (64 GiB class) |
| GPU / driver | AMD Radeon RX 580 2048SP; DirectX diagnostic reports 8,170 MB dedicated memory; driver 31.0.21925.1001, dated 2026-05-20 |
| Forward+ | Vulkan 1.3.260, AMD RX 580 2048SP |
| Compatibility | OpenGL 3.3 core, driver string 26.5.2.260413, same GPU |
| Tool versions | Godot 4.8.beta3.official.c51ff06e8; matching Standard templates; Blender 5.2.3 LTS e13b728c6880; PowerShell 7.6.9; Python 3.14.0; Git 2.56.0.windows.4 |
| Rights | Unelevated medium-integrity process; administrator group present only as deny-only. Local writes, HTTPS downloads and graphical launches worked without elevation |
| Storage | At inventory, approximately 324 GB free on the system volume and 2.9 TB on the project volume; sufficient for local tools and clean-checkout verification |

WMI reports approximately 4 GiB AdapterRAM, while the separate Windows DirectX diagnostic reports 8,170 MB dedicated memory. The latter is the recorded VRAM observation; neither is a player minimum. The desktop mode is 1920×1080 at 144 Hz; the probe viewport is 960×640. The raw diagnostic remains local in `.artifacts/dxdiag.txt`. No driver update, system-wide configuration, security change, purchase, WSL or container was used.

Technical package 0.2.1 records the owner’s replacement of T-002 with direct Windows 11 development. P0 selects tested beta 3 under existing T-009/010 rather than waiting for stable or pinning the older beta 2 without testing the current candidate. Blender LTS is pinned after a successful source/import check. Small source assets are committed directly with a manifest; no asset-storage service is needed yet. See [workflow and upstream sources](03-windows-development.md).

## Checks and evidence

Commands are documented in the [Windows workflow](03-windows-development.md). Generated logs, screenshots, binaries and local inventory remain in ignored `.artifacts/`; no absolute profile path or temporary output is needed by source.

| Check | Result / evidence |
|---|---|
| Portable setup | Three archives verified against pinned release hashes; fresh local extraction; no admin or global install |
| Source asset | Original 98,092-byte `.blend` and 5,112-byte GLB, provenance and SHA-256 in `art/p0-probe.json` |
| Blender source → GLB | `asset-rebuild.log`: reopening the committed source and exporting produces the exact committed GLB hash, `P0_ASSET_REBUILD_PASS` |
| Headless import | `import.log`: successful fresh resource import |
| Typed GDScript contract | `tests.log`: two meshes, expected topology/normals, metres, Y-up transform, identity scale/rotation, preserved material color, two-second Pulse and quarter-cycle samples; `P0_TEST_PASS` |
| Headless main-scene startup | `headless-startup.log`: main scene loads and imported animation advances, `P0_SMOKE_PASS` |
| GDD package | `design.log`: zero errors; documents/examples only, separate from game tests |
| Release export | `export.log`: Windows Desktop x86-64 release generated successfully; PE machine field independently inspected as `0x8664` (AMD64) |
| Real project launch | `project-forward_plus.log` and screenshot: Windows display, Vulkan Forward+, correct colored geometry and readable text, imported animation advances, clean exit |
| Independent executable launch | `export-forward_plus.log` and screenshot: exported release executed directly, without editor or `--path`; Windows display and Forward+, animation advances, clean exit |
| Lightweight renderer | Project and exported executable also launch with Compatibility; `project-gl_compatibility.log`, `export-gl_compatibility.log` and screenshots |
| Clean checkout | Fresh local clone of committed implementation `4783c4c`, setup from verified archives, asset rebuild, fresh import, tests, release export and both real graphical launch paths all passed; Git status remained empty |

The process wrapper rejects nonzero exit codes, script/engine errors and absent success markers. All final engine/import/runtime checks report no critical errors. Screenshots were visually inspected, including the separately launched export. The font fallback uses MSDF after an initial Compatibility screenshot revealed missing glyphs with the default rasterized font. Blender frame range was corrected from 1–61 to 0–60: the original GLB began at 1/30 second and imported as 2.033 seconds; final tests enforce the intended zero-origin two-second clip. Material checks use glTF linear color converted to Godot’s sRGB property representation.

`.gitattributes` resolves Windows Git CRLF conversion without weakening the documentation validator. The validator now prunes `.tools`, `.artifacts`, `.godot` and Python caches instead of attempting to validate bundled third-party files as project design documents.

## Scope and readiness

No gameplay rules changed. No calendar, soul/body state, save protocol, combat or P1–P10 system is implemented or claimed tested. The technical scene is an import/runtime fixture, not a gameplay slice. There are no current campaign saves to migrate.

P1 / VS-01 can proceed once this foundation is reviewed. It must resolve/test the remaining OPEN-01 calendar conventions and OPEN-10 snapshot/recovery details, then verify the relevant AT-TIME, AT-SOUL and AT-SAVE scenarios. The foundation provides execution, import, typed-script tests and Windows build commands; it does not prove those future rules.

Machine B, physical transfer to another machine, minimum player requirements, dense-scene performance, flight, streaming, long GPU runs and production character rigs remain untested. The tiny 960×640 probe does not close VISION-09 or prove the 1080p/60 fps performance hypothesis. Stable Godot migration remains a separately tested change under T-010. No unavailable hardware is treated as a blocker for the owner’s current Windows-only P0 criteria.

## Completion record

The clean-checkout script finished with `P0_CLEAN_CHECKOUT_PASS`; its directory name contained spaces, and its tools/imports/exports were extracted or generated afresh. The source implementation tested was commit `4783c4c`; subsequent completion edits update only documentation, with the design validator rerun. The branch is published as `origin/work/p0-foundation`; no merge into `master` is part of P0. The final commit ID is available from Git rather than embedded into its own contents. All nine requested P0 criteria are satisfied on the available Windows 11 machine, within the explicit hardware and performance limits above.
