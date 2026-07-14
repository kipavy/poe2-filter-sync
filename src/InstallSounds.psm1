function Install-Sounds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SoundsDir,
        [Parameter(Mandatory)][object]$Mapping,
        [Parameter(Mandatory)][string]$Poe2Dir
    )
    if (-not (Test-Path $Poe2Dir)) { New-Item -ItemType Directory -Path $Poe2Dir -Force | Out-Null }
    $written = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $Mapping.FileReplacements.GetEnumerator()) {
        $src = Join-Path $SoundsDir $entry.Value
        $dst = Join-Path $Poe2Dir $entry.Key
        Copy-Item -Path $src -Destination $dst -Force
        $written.Add($dst)
    }
    foreach ($o in $Mapping.TargetedOverrides) {
        $src = Join-Path $SoundsDir $o.File
        $dst = Join-Path $Poe2Dir $o.File
        Copy-Item -Path $src -Destination $dst -Force
        $written.Add($dst)
    }
    return $written.ToArray()
}
Export-ModuleMember -Function Install-Sounds
