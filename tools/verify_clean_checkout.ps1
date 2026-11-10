#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Python = 'python',
    [string]$Branch = '',
    [ValidateSet('P0','P1')][string]$Phase = 'P0'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $root ('.artifacts/clean checkout ' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (!$Branch) { $Branch = (& git -C $root branch --show-current).Trim() }
if (!$Branch) { throw 'Specify -Branch for a detached checkout' }
& git clone --no-hardlinks --branch $Branch $root $destination
if ($LASTEXITCODE -ne 0) { throw 'Clone failed' }
# Only verified download archives are reused; no imported caches or installed binaries.
$downloads = Join-Path $destination '.tools/downloads'
New-Item $downloads -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $root '.tools/downloads/*') -Destination $downloads
& pwsh -NoProfile -File (Join-Path $destination 'tools/p0.ps1') -Task Setup -Python $Python
if ($LASTEXITCODE -ne 0) { throw 'Clean setup failed' }
& pwsh -NoProfile -File (Join-Path $destination "tools/$($Phase.ToLower()).ps1") -Task Verify -Python $Python
if ($LASTEXITCODE -ne 0) { throw 'Clean verification failed' }
if ($Phase -eq 'P0') {
    & pwsh -NoProfile -File (Join-Path $destination 'tools/p0.ps1') -Task Smoke -Renderer gl_compatibility -Python $Python
    if ($LASTEXITCODE -ne 0) { throw 'Clean compatibility check failed' }
}
$status = & git -C $destination status --porcelain
if ($status) { throw "Verification changed tracked source: $status" }
Write-Output "$($Phase)_CLEAN_CHECKOUT_PASS $destination"
