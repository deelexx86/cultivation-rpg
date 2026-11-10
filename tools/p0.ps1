#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Setup','Doctor','Asset','AssetCheck','Import','Test','Run','Export','Smoke','Verify')]
    [string]$Task,
    [ValidateSet('forward_plus','gl_compatibility')][string]$Renderer = 'forward_plus',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content (Join-Path $PSScriptRoot 'toolchain.json') -Raw | ConvertFrom-Json
$godot = Join-Path $root ".tools/$($lock.godot.executable)"
$blender = Join-Path $root ".tools/$($lock.blender.executable)"
$game = Join-Path $root 'game'
$artifacts = Join-Path $root '.artifacts'
New-Item $artifacts -ItemType Directory -Force | Out-Null

function Check([string]$Name, [string]$Marker, [string[]]$Command) {
    & $Python (Join-Path $PSScriptRoot 'run_process.py') --log (Join-Path $artifacts "$Name.log") --marker $Marker -- @Command
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE)" }
}

function Import-Project {
    Check 'import' '' @($godot, '--headless', '--path', $game, '--import')
}

function Test-Asset {
    Check 'asset-rebuild' 'P0_ASSET_REBUILD_PASS' @($blender, '--background', '--factory-startup', '--python-exit-code', '1', '--python', (Join-Path $PSScriptRoot 'verify_probe.py'))
}

function Test-Project {
    Check 'tests' 'P0_TEST_PASS' @($godot, '--headless', '--path', $game, '--script', 'res://tests/run_tests.gd')
    Check 'headless-startup' 'P0_SMOKE_PASS' @($godot, '--headless', '--path', $game, '--', '--smoke')
    Check 'design' 'Errors: 0' @($Python, (Join-Path $PSScriptRoot 'validate_design.py'))
}

function Export-Project {
    New-Item (Join-Path $artifacts 'windows') -ItemType Directory -Force | Out-Null
    Check 'export' '' @($godot, '--headless', '--path', $game, '--export-release', 'Windows x86-64',
        (Join-Path $artifacts 'windows/CultivationRPG.exe'))
    if (!(Test-Path (Join-Path $artifacts 'windows/CultivationRPG.exe'))) { throw 'Export missing' }
}

function Smoke-Project {
    Check "project-$Renderer" 'P0_SMOKE_PASS' @($godot, '--path', $game, '--rendering-method', $Renderer,
        '--', '--smoke', "--capture=$(Join-Path $artifacts "project-$Renderer.png")")
    # Independent executable: no --path and no editor binary.
    $executable = Join-Path $artifacts 'windows/CultivationRPG.exe'
    Check "export-$Renderer" 'P0_SMOKE_PASS' @($executable, '--rendering-method', $Renderer,
        '--', '--smoke', "--capture=$(Join-Path $artifacts "export-$Renderer.png")")
}

Push-Location $root
try {
    if ($Task -eq 'Setup') {
        & $Python (Join-Path $PSScriptRoot 'setup_toolchain.py')
        if ($LASTEXITCODE -ne 0) { throw 'Setup failed' }
        exit 0
    }
    if ($Task -eq 'Doctor') {
        $os = Get-CimInstance Win32_OperatingSystem
        [ordered]@{
            os = $os.Caption; version = $os.Version; build = $os.BuildNumber
            cpu = (Get-CimInstance Win32_Processor).Name
            ram_bytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
            gpu = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,AdapterRAM)
            powershell = $PSVersionTable.PSVersion.ToString()
            python = (& $Python --version); git = (& git --version)
            godot = (& $godot --version)
            blender = (& $blender --background --factory-startup --version | Select-Object -First 1)
            elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
        } | ConvertTo-Json -Depth 4 | Tee-Object (Join-Path $artifacts 'environment.json')
        exit 0
    }
    if (!(Test-Path $godot)) { throw 'Run -Task Setup first' }
    $version = & $godot --version
    if (!$version.StartsWith($lock.godot.version + '.')) { throw "Unexpected Godot: $version" }
    switch ($Task) {
        'Asset' { Check 'blender' 'P0_ASSET_EXPORTED' @($blender, '--background', '--factory-startup', '--python-exit-code', '1', '--python', (Join-Path $PSScriptRoot 'create_probe.py')) }
        'AssetCheck' { Test-Asset }
        'Import' { Import-Project }
        'Test' { Test-Project }
        'Run' { & $godot --path $game; if ($LASTEXITCODE -ne 0) { throw 'Project failed' } }
        'Export' { Export-Project }
        'Smoke' { Smoke-Project }
        'Verify' { Test-Asset; Import-Project; Test-Project; Export-Project; Smoke-Project }
    }
} finally { Pop-Location }
