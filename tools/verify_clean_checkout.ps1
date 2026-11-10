#requires -Version 7.0
[CmdletBinding()]
param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path $PSScriptRoot -Parent
$destination = Join-Path $root ('.artifacts/clean checkout ' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
& git clone --no-hardlinks --branch work/p0-foundation $root $destination
if ($LASTEXITCODE -ne 0) { throw 'Clone failed' }
# Only verified download archives are reused; no imported caches or installed binaries.
$downloads = Join-Path $destination '.tools/downloads'
New-Item $downloads -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $root '.tools/downloads/*') -Destination $downloads
& pwsh -NoProfile -File (Join-Path $destination 'tools/p0.ps1') -Task Setup -Python $Python
if ($LASTEXITCODE -ne 0) { throw 'Clean setup failed' }
& pwsh -NoProfile -File (Join-Path $destination 'tools/p0.ps1') -Task Verify -Python $Python
if ($LASTEXITCODE -ne 0) { throw 'Clean verification failed' }
& pwsh -NoProfile -File (Join-Path $destination 'tools/p0.ps1') -Task Smoke -Renderer gl_compatibility -Python $Python
if ($LASTEXITCODE -ne 0) { throw 'Clean compatibility check failed' }
$status = & git -C $destination status --porcelain
if ($status) { throw "Verification changed tracked source: $status" }
Write-Output "P0_CLEAN_CHECKOUT_PASS $destination"
