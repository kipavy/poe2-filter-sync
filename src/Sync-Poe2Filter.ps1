#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Full,
    [string]$Poe2Dir = (Join-Path $env:USERPROFILE 'Documents\My Games\Path of Exile 2'),
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/SoundMapping.psm1" -Force
Import-Module "$PSScriptRoot/InstallSounds.psm1" -Force

$soundsDir = Join-Path $RepoRoot 'sounds'
$cfgPath   = Join-Path $RepoRoot 'config/sound-mapping.json'
$mapping   = Get-SoundMapping -Path $cfgPath -SoundsDir $soundsDir

Write-Host "Installing custom sounds into: $Poe2Dir"
Install-Sounds -SoundsDir $soundsDir -Mapping $mapping -Poe2Dir $Poe2Dir | Out-Null
Write-Host "Sounds installed."

if (-not $Full) {
    # Default mode: open the filter page(s) so the user can subscribe/follow in one click.
    foreach ($url in $mapping.FollowUrls) {
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            Write-Host "Opening filter page to subscribe: $url"
            Start-Process $url
        }
    }
}

if ($Full) {
    Import-Module "$PSScriptRoot/NeverSink.psm1" -Force
    Import-Module "$PSScriptRoot/BuildFilter.psm1" -Force
    $work = Join-Path ([System.IO.Path]::GetTempPath()) 'poe2-filter-build'
    Write-Host "Downloading NeverSink..."
    $styleDir = Get-NeverSinkFilterDir -DestDir $work
    $srcFilter = Find-SourceFilter -Dir $styleDir -Match $mapping.SourceFilterMatch
    $built = Build-Filter -SourceFilterPath $srcFilter -Mapping $mapping -OutDir $work
    $dest = Join-Path $Poe2Dir ("{0}.filter" -f $mapping.PoeFilterName)
    Copy-Item -Path $built.FilterPath -Destination $dest -Force
    Write-Host "Full build installed locally: $dest"
}
