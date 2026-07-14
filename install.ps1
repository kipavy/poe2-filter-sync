#requires -Version 5.1
[CmdletBinding()]
param([switch]$Full)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$repoZip = 'https://github.com/kipavy/poe2-filter-sync/archive/refs/heads/main.zip'
$work = Join-Path ([System.IO.Path]::GetTempPath()) 'poe2-filter-sync'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
$zip = Join-Path $work 'repo.zip'
Invoke-WebRequest -Uri $repoZip -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $work -Force
$root = Get-ChildItem -Path $work -Directory | Where-Object Name -like 'poe2-filter-sync-*' | Select-Object -First 1
if (-not $root) { throw "Extracted repo folder not found under $work" }
& (Join-Path $root.FullName 'src/Sync-Poe2Filter.ps1') -Full:$Full -RepoRoot $root.FullName
