#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Demo','Test','Crash','Smoke','Verify')][string]$Task='Demo',[string]$Python='python',[ValidatePattern('^[a-zA-Z0-9_-]{1,64}$')][string]$Campaign='white-sedge')
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$lock=Get-Content "$PSScriptRoot/toolchain.json" -Raw | ConvertFrom-Json
$engine=Join-Path $root ".tools/$($lock.godot.executable)"
$game=Join-Path $root game
$out=Join-Path $root .artifacts
function Check($name,$marker,$arguments) {
    & $Python "$PSScriptRoot/run_process.py" --log "$out/$name.log" --marker $marker -- @arguments
    if ($LASTEXITCODE) { throw "$name failed" }
}
if (!(Test-Path $engine)) {
    & pwsh -NoProfile -File "$PSScriptRoot/p0.ps1" -Task Setup
    if ($LASTEXITCODE) { throw 'Toolchain setup failed' }
}
if ($Task -eq 'Verify') {
    & pwsh -NoProfile -File "$PSScriptRoot/p2.ps1" -Task Verify -Python $Python
    if ($LASTEXITCODE) { throw 'P0-P2 regression failed' }
}
if ($Task -in 'Demo','Test') {
    Check 'p3-import' '' @($engine,'--headless','--path',$game,'--import')
}
if ($Task -eq 'Demo') {
    & $engine --path $game -- --p3 "--campaign=$Campaign"
    exit $LASTEXITCODE
}
if ($Task -in 'Verify','Test') {
    Check 'p3-rules' 'P3_RULE_PASS' @($engine,'--headless','--path',$game,'--script','res://tests/material_tests.gd')
}
if ($Task -in 'Verify','Crash') {
    Check 'p3-crashes' 'P3_CRASH_PASS' @($Python,"$PSScriptRoot/verify_material_crashes.py",'--godot',$engine,'--game',$game,'--output',$out)
}
if ($Task -in 'Verify','Smoke') {
    foreach ($renderer in 'forward_plus','gl_compatibility') {
        $slot=[guid]::NewGuid().ToString('N')
        Check "p3-project-$renderer" 'P3_SCENE_PASS' @($engine,'--path',$game,'--rendering-method',$renderer,'--','--p3','--p3-smoke',"--capture=$out/p3-project-$renderer","--slot=$slot")
        $exe="$out/windows/CultivationRPG.exe"
        Check "p3-resume-$renderer" 'P3_RESUME_PASS' @($exe,'--rendering-method',$renderer,'--','--p3','--p3-smoke','--resume-check',"--capture=$out/p3-resume-$renderer","--slot=$slot")
        $exportSlot=[guid]::NewGuid().ToString('N')
        Check "p3-export-$renderer" 'P3_SCENE_PASS' @($exe,'--rendering-method',$renderer,'--','--p3','--p3-smoke',"--slot=$exportSlot")
        Check "p3-export-resume-$renderer" 'P3_RESUME_PASS' @($exe,'--rendering-method',$renderer,'--','--p3','--p3-smoke','--resume-check',"--slot=$exportSlot")
        Check "p3-condense-$renderer" 'P3_CONDENSE_PASS' @($exe,'--rendering-method',$renderer,'--','--p3','--p3-smoke','--intact-route',"--capture=$out/p3-condense-$renderer")
        Check "p3-property-$renderer" 'P3_PROPERTY_PASS' @($exe,'--rendering-method',$renderer,'--','--p3','--p3-smoke','--property-route')
    }
}
if ($Task -eq 'Verify') { Write-Output 'P3_VERIFY_PASS' }
