#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Demo','Test','Smoke','Verify')][string]$Task = 'Demo',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lock = Get-Content "$PSScriptRoot/toolchain.json" -Raw | ConvertFrom-Json
$engine = Join-Path $root ".tools/$($lock.godot.executable)"
$game = Join-Path $root game
$out = Join-Path $root .artifacts
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
if ($Task -eq 'Verify') { Phase p4 Verify } else { Phase p0 Import }
if ($Task -eq 'Demo') { & $engine --path $game; exit $LASTEXITCODE }
if ($Task -in 'Verify','Test') {
    Check 'p5-rules' 'P5_RULE_PASS' @($engine,'--headless','--path',$game,'--script','res://tests/slice_tests.gd')
    & $Python "$PSScriptRoot/verify_material_crashes.py" --slice --godot $engine --game $game --output $out
    if ($LASTEXITCODE) { throw 'P5 crash recovery failed' }
}
if ($Task -eq 'Smoke') { Phase p0 Export }
if ($Task -in 'Verify','Smoke') {
    $tag = [guid]::NewGuid().ToString('N').Substring(0,12)
    foreach ($method in 'condense','smooth') {
        $renderer = if ($method -eq 'smooth') { 'gl_compatibility' } else { 'forward_plus' }
        $seed = if ($method -eq 'smooth') { 'vs_smooth_no_overload' } else { 'vs-root-whole' }
        $argsUi = @($exe,'--rendering-method',$renderer,'--resolution','960x640','--fixed-fps','30','--','--p5-tour',"--campaign=qa-$tag-$method","--seed=$seed","--capture=$out/p5-$method")
        if ($method -eq 'condense') {
            Check 'p5-condense' 'P5_FIRST_FOUNDATION method=condense' ($argsUi + '--condense')
        } else {
            Check 'p5-smooth' 'P5_WINDUP_SAVED' $argsUi
            Check 'p5-combat-resume' 'P5_DEATH_SAVED' ($argsUi + '--finish-combat')
            Check 'p5-transfer' 'P5_TRANSFER_SAVED' $argsUi
            Check 'p5-second-life' 'P5_REBIRTH_PASS' $argsUi
        }
    }
    Write-Output 'P5_EXPORT_PASS'
}
if ($Task -eq 'Verify') { Write-Output 'P5_VERIFY_PASS' }
