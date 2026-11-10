#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Test','Crash','Demo','DemoSmoke','Smoke','Verify')][string]$Task,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$godot = Join-Path $root ".tools/$($lock.godot.executable)"
$game = Join-Path $root 'game'
$artifacts = Join-Path $root '.artifacts'
New-Item $artifacts -ItemType Directory -Force | Out-Null

function Check([string]$Name, [string]$Marker, [string[]]$Command) {
    & $Python (Join-Path $PSScriptRoot 'run_process.py') --log (Join-Path $artifacts "$Name.log") --marker $Marker -- @Command
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE)" }
}
function Test-Core {
    Check 'p1-tests' 'P1_TEST_PASS' @($godot, '--headless', '--path', $game, '--script', 'res://tests/p1_tests.gd')
}
function Test-Crash {
    Check 'p1-crashes' 'P1_CRASH_PASS' @($Python, (Join-Path $PSScriptRoot 'verify_p1_crashes.py'), '--godot', $godot, '--game', $game, '--output', $artifacts)
}
function Test-Demo {
    Check 'p1-demo-headless' 'P1_DEMO_PASS' @($godot, '--headless', '--path', $game, '--', '--p1-demo-smoke')
}
function Test-Windows {
    foreach ($renderer in @('forward_plus', 'gl_compatibility')) {
        Check "p1-project-$renderer" 'P1_DEMO_PASS' @($godot, '--path', $game, '--rendering-method', $renderer, '--', '--p1-demo-smoke', "--capture=$(Join-Path $artifacts "p1-project-$renderer.png")")
        Check "p1-export-$renderer" 'P1_DEMO_PASS' @((Join-Path $artifacts 'windows/CultivationRPG.exe'), '--rendering-method', $renderer, '--', '--p1-demo-smoke', "--capture=$(Join-Path $artifacts "p1-export-$renderer.png")")
    }
}
Push-Location $root
try {
    if (!(Test-Path $godot)) { throw 'Run tools/p0.ps1 -Task Setup first' }
    $version = & $godot --version
    if (!$version.StartsWith($lock.godot.version + '.')) { throw "Unexpected Godot: $version" }
    switch ($Task) {
        'Test' { Test-Core }
        'Crash' { Test-Crash }
        'DemoSmoke' { Test-Demo }
        'Smoke' { Test-Windows }
        'Demo' { & $godot --path $game -- --p1-demo; if ($LASTEXITCODE -ne 0) { throw 'Demo failed' } }
        'Verify' {
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'p0.ps1') -Task Verify -Python $Python
            if ($LASTEXITCODE -ne 0) { throw 'P0 regression failed' }
            & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'p0.ps1') -Task Smoke -Renderer gl_compatibility -Python $Python
            if ($LASTEXITCODE -ne 0) { throw 'P0 compatibility regression failed' }
            Test-Core
            Test-Crash
            Test-Demo
            Test-Windows
            Write-Output 'P1_VERIFY_PASS'
        }
    }
} finally { Pop-Location }
