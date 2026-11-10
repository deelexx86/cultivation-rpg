# Windows 11 development

**Status:** P0 / VS-00 implementation, 2026-11-10. Owner decision T-002: development takes place directly on Windows 11. GDD 0.14.1 and the accepted gameplay architecture remain unchanged.

## Prerequisites and pinned tools

Use Windows 11 x86-64, a working GPU driver, Git, PowerShell 7 and Python 3.11 or newer (standard library only). This environment was tested with PowerShell **7.6.9**, Python **3.14.0**, and Git **2.56.0.windows.4**. Other prerequisite versions have not been tested. No compiler SDK, package manager, Python packages or administrator elevation is required. `pwsh`, `python`, and `git` must be available on PATH; `-Python` can select another Python executable. Do not use the Windows Store alias if Python is not installed.

The [tool lock](../../tools/toolchain.json) fixes download URLs, versions and hashes:

| Component | Selected version | Reason |
|---|---|---|
| Godot Standard Windows x86-64 | 4.8 beta 3, official `c51ff06e8` | Current tested 4.8 candidate, permitted by T-009/010; [published 9 November](https://godotengine.org/download/archive/4.8-beta3/). The target 4.8 stable is not yet available |
| Windows debug/release export templates | Matching 4.8 beta 3 | Same official release, SHA-512-verified archive; only x86-64 Windows executables and version metadata are extracted |
| Blender portable | 5.2.3 LTS, `e13b728c6880` | Stable supported production line; successfully tested original source, animated GLB, materials and scale. [Blender LTS](https://www.blender.org/download/lts/) |

The [Godot archive](https://godotengine.org/download/archive/) lists 4.7.2 as the current stable line. It remains the T-010 fallback; no blocker justified switching away from the accepted 4.8 target. Godot archive hashes come from the release’s [SHA512-SUMS](https://github.com/godotengine/godot-builds/releases/download/4.8-beta3/SHA512-SUMS.txt). Blender’s SHA-256 comes from the [release checksum file](https://ftp.nluug.nl/pub/graphics/blender/release/Blender5.2/blender-5.2.3.sha256). The Blender host uses the enabled [NLUUG mirror](https://projects.blender.org/infrastructure/mirror/wiki); the primary download host failed TLS/access checks in this environment. Certificate verification remains enabled. No automatic upgrade or fallback to a different version occurs.

The setup writes only `.tools/` inside the checkout, verifies downloads before extraction and verifies/re-extracts cached archives on repeated setup. Nothing is installed globally; existing application settings and the global export-template directory are untouched. Downloads total about 1.83 GB; allow roughly 6 GB of free disk for tools, caches and output, and more for the clean-checkout copy. The all-platform template archive is an upstream packaging cost, not a multi-OS support requirement.

## Commands

From the repository root in PowerShell 7:

```powershell
pwsh -NoProfile -File tools/p0.ps1 -Task Setup
pwsh -NoProfile -File tools/p0.ps1 -Task Doctor
pwsh -NoProfile -File tools/p0.ps1 -Task Verify
pwsh -NoProfile -File tools/p0.ps1 -Task Run
```

`Verify` rebuilds a temporary GLB from the committed `.blend` and verifies its hash, imports the project without a window, runs the GDScript asset contract, launches the main scene headlessly, validates design documentation, exports a release Windows executable, and launches both the project and the exported executable with a real graphical window. Smoke mode verifies animation advancement, captures a rendered frame and exits automatically. These are short technical probes, not gameplay or performance tests.

Individual operations:

```powershell
pwsh -NoProfile -File tools/p0.ps1 -Task AssetCheck
pwsh -NoProfile -File tools/p0.ps1 -Task Import
pwsh -NoProfile -File tools/p0.ps1 -Task Test
pwsh -NoProfile -File tools/p0.ps1 -Task Export
pwsh -NoProfile -File tools/p0.ps1 -Task Smoke
pwsh -NoProfile -File tools/p0.ps1 -Task Smoke -Renderer gl_compatibility
python tools/validate_design.py
```

`Test` expects imported resources; run `Import` first after a fresh clone. `Smoke` expects an existing export; run `Export` first after changing source. `Run` launches the main scene interactively and exits when its window closes. To edit it in Godot:

```powershell
& ./.tools/godot/Godot_v4.8-beta3_win64_console.exe --editor --path ./game
```

The build is `.artifacts/windows/CultivationRPG.exe` with its adjacent `CultivationRPG.pck`. Distribute both together. It can be launched directly in Explorer or:

```powershell
& ./.artifacts/windows/CultivationRPG.exe
```

The release is unsigned and local; no distribution service or signing certificate is required for P0. Export presets use relative custom-template paths into `.tools/`. No per-user template installation is needed. Game runtime does not require Blender, Python or the editor.

Every automated process has a 120-second timeout, checks its exit code and scans output for engine/script errors; smoke/tests also require explicit success markers. Any failure makes the PowerShell command fail. Logs and screenshots are in `.artifacts/`. Inspect screenshots as well as logs: absence of engine errors does not establish visual correctness. `Doctor` writes local hardware/tool inventory there without committing profile paths.

## Clean checkout

After committing changes on `work/p0-foundation`:

```powershell
pwsh -NoProfile -File tools/verify_clean_checkout.ps1
```

This creates a fresh Git clone in an ignored directory whose name includes spaces. Only cached download archives are copied; setup rechecks their hashes and freshly extracts tools. No `.godot` cache, installed binaries or earlier exports are copied. The clone rebuilds the asset, imports, tests, exports, runs both rendering probes and checks that Git remains clean. It validates committed HEAD, not uncommitted work. Network-free use requires those verified archives to have been downloaded already. An independent machine can instead clone the branch and run `Setup` normally; that physical second-machine test has not been performed.

`.gitattributes` enforces LF even when global `core.autocrlf` is enabled. Source is UTF-8; paths are derived from the scripts’ location. The design validator excludes local tool installs, build output and Godot caches. `.godot/`, `.tools/`, `.artifacts/`, backups and export credentials are ignored; small `.uid` and GLB import settings are tracked.

## Asset authoring and architectural boundary

The original fixture consists of two material-colored cubes and a two-second vertical animation. Its [manifest](../../art/p0-probe.json) records origin, hashes, dimensions, units and clips. Source lives under `art/source/`, outside Godot; the prepared GLB is under `game/assets/`. No external model, texture, service or runtime generation is involved. Both files are small enough for ordinary Git. Large future asset collections will need a separate storage decision.

`AssetCheck` opens the committed source in Blender and exports a temporary GLB that must exactly match the committed hash. To intentionally recreate the source from the authoring recipe:

```powershell
pwsh -NoProfile -File tools/p0.ps1 -Task Asset
```

This is an authoring operation: review the resulting source/GLB, update the manifest hashes if changed, then run `Verify`. `.blend` bytes can change because of Blender metadata; the prepared GLB is the reproducibility boundary.

`game/scenes/` owns only presentation and the technical startup probe. `game/tests/` checks the import boundary. No empty domain/application/infrastructure modules, calendar, campaign state, combat, saves, content catalog or Autoload framework have been introduced. Future P1 rules belong in typed scene-independent domain code with application coordination and infrastructure adapters, per the accepted architecture.

Forward+ is the selected P0 default. Compatibility is a verified lightweight technical fallback, without a promise of later effect parity. The probe uses MSDF font rendering to avoid missing text glyphs observed with the default font rasterization on this AMD/OpenGL driver. Its English technical labels are development diagnostics; the accepted Russian gameplay-prototype language is unchanged.
