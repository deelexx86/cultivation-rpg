#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Demo','Test','Smoke','Verify')][string]$Task='Demo',[string]$Python='python',[ValidatePattern('^[a-zA-Z0-9_-]{1,64}$')][string]$Campaign='white-sedge')
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
    & pwsh -NoProfile -File "$PSScriptRoot/p1.ps1" -Task Verify -Python $Python
    if ($LASTEXITCODE) { throw 'P0/P1 regression failed' }
}
if ($Task -eq 'Demo') {
    & $engine --headless --path $game --import
    if ($LASTEXITCODE) { throw 'Import failed' }
    & $engine --path $game -- --p2 "--campaign=$Campaign"
    exit $LASTEXITCODE
}
if ($Task -in 'Verify','Test') {
    Check 'p2-assets' 'P2_ASSETS_PASS' @($Python,"$PSScriptRoot/verify_sedge_assets.py")
    Check 'p2-rules' 'P2_RULE_PASS' @($engine,'--headless','--path',$game,'--script','res://tests/sedge_tests.gd')
}
if ($Task -in 'Verify','Smoke') {
    foreach ($renderer in 'forward_plus','gl_compatibility') {
        $slot = [guid]::NewGuid().ToString("N")
        Check "p2-project-$renderer" 'P2_SCENE_PASS' @($engine,'--path',$game,'--rendering-method',$renderer,'--','--p2','--p2-smoke',"--capture=$out/project-$renderer","--slot=$slot")
        $exe = "$out/windows/CultivationRPG.exe"
        Check "p2-resume-$renderer" 'P2_RESUME_PASS' @($exe,'--rendering-method',$renderer,'--','--p2','--p2-smoke','--resume-check',"--slot=$slot")
        Check "p2-export-$renderer" 'P2_SCENE_PASS' @($exe,'--rendering-method',$renderer,'--','--p2','--p2-smoke',"--capture=$out/export-$renderer")
    }
}
