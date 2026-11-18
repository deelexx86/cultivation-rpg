#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Demo','Test','Smoke','Verify')][string]$Task = 'Demo',
    [ValidateSet('qi','foundation','core','soul')][string]$Rank = 'qi',
    [ValidatePattern('^[a-zA-Z0-9_-]{1,64}$')][string]$Campaign,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content "$PSScriptRoot/toolchain.json" -Raw | ConvertFrom-Json
$engine = Join-Path $root ".tools/$($lock.godot.executable)"
$game = Join-Path $root game
$out = Join-Path $root .artifacts
$exe = Join-Path $out 'windows/CultivationRPG.exe'

function Check($name, $marker, $arguments) {
    & $Python "$PSScriptRoot/run_process.py" --log "$out/$name.log" --marker $marker -- @arguments
    if ($LASTEXITCODE) { throw "$name failed" }
}
function Run-Phase($phase, $task) {
    & pwsh -NoProfile -File "$PSScriptRoot/$phase.ps1" -Task $task -Python $Python
    if ($LASTEXITCODE) { throw "$phase/$task failed" }
}

if (!(Test-Path $engine)) { Run-Phase p0 Setup }
if ($Task -eq 'Verify') { Run-Phase p3 Verify }
if ($Task -in 'Demo','Test','Smoke') {
    Check 'p4-import' '' @($engine,'--headless','--path',$game,'--import')
}
if ($Task -eq 'Demo') {
    $launch = @('--p4', "--rank=$Rank")
    if ($Campaign) { $launch += "--campaign=$Campaign" }
    & $engine --path $game -- @launch
    exit $LASTEXITCODE
}
if ($Task -in 'Test','Verify') {
    Check 'p4-rules' 'P4_RULE_PASS' @($engine,'--headless','--path',$game,'--script','res://tests/combat_tests.gd')
}
if ($Task -in 'Smoke','Verify') {
    if ($Task -eq 'Smoke') { Run-Phase p0 Export }
    & $Python "$PSScriptRoot/verify_combat_ui.py" --godot $engine --game $game --export $exe --output $out
    if ($LASTEXITCODE) { throw 'Windows gameplay verification failed' }
}
if ($Task -eq 'Verify') { Write-Output 'P4_VERIFY_PASS' }
