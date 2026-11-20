#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Demo','Test','Smoke','Verify')][string]$Task = 'Demo',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$game = Join-Path $root game
$out = Join-Path $root .artifacts
$lock = Get-Content "$PSScriptRoot/toolchain.json" -Raw | ConvertFrom-Json
$engine = Join-Path $root ".tools/$($lock.godot.executable)"
$exe = Join-Path $out 'windows/CultivationRPG.exe'

function Phase($phase,$action) {
    & pwsh -NoProfile -File "$PSScriptRoot/$phase.ps1" -Task $action -Python $Python
    if ($LASTEXITCODE) { throw "$phase/$action failed" }
}
function Check($name,$marker,$arguments) {
    & $Python "$PSScriptRoot/run_process.py" --timeout 360 --log "$out/$name.log" --marker $marker -- @arguments
    if ($LASTEXITCODE) { throw "$name failed" }
}
if (!(Test-Path $engine)) { Phase p0 Setup }
if ($Task -eq 'Verify') { Phase p5 Verify } else { Phase p0 Import }
if ($Task -eq 'Demo') { & $engine --path $game; exit $LASTEXITCODE }
if ($Task -in 'Verify','Test') {
    foreach ($run in 1..2) {
        Check "p71-rules-$run" 'P71_RULE_PASS' @($engine,'--headless','--path',$game,'--script','res://tests/character_tests.gd')
    }
}
if ($Task -eq 'Smoke') { Phase p0 Export }
if ($Task -in 'Verify','Smoke') {
    $tag = [guid]::NewGuid().ToString('N').Substring(0,12)
    foreach ($rank in 'initial','foundation') {
        $id = "qa-bolt-$rank-$tag"
        Check "p71-fixture-$rank" 'P71_COMBAT_FIXTURE' @($engine,'--headless','--path',$game,'--script','res://tests/character_combat_fixture.gd','--',$id,$rank)
        Check "p71-bolt-$rank" 'P71_BOLT_PASS' @($exe,'--rendering-method','forward_plus','--resolution','960x640','--fixed-fps','30','--','--p5-tour','--measure-bolt',"--campaign=$id")
    }
    $tour = @($exe,'--rendering-method','gl_compatibility','--resolution','960x640','--fixed-fps','30','--','--p5-tour','--character',"--campaign=qa-trained-$tag",'--seed=vs_smooth_no_overload',"--capture=$out/p71")
    Check 'p71-first-life' 'P5_WINDUP_SAVED' $tour
    Check 'p71-death' 'P5_DEATH_SAVED' ($tour + '--finish-combat')
    Check 'p71-transfer' 'P5_TRANSFER_SAVED' $tour
    Check 'p71-second-life' 'P5_REBIRTH_PASS' $tour
    Write-Output 'P71_EXPORT_PASS'
}
if ($Task -eq 'Verify') { Write-Output 'P71_VERIFY_PASS' }
