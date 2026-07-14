function Get-NeverSinkFilterDir {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DestDir)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (Test-Path $DestDir) { Remove-Item $DestDir -Recurse -Force }
    New-Item -ItemType Directory -Path $DestDir | Out-Null

    $zipUrl = 'https://github.com/NeverSinkDev/NeverSink-Filter-for-PoE2/archive/refs/heads/main.zip'
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/NeverSinkDev/NeverSink-Filter-for-PoE2/releases/latest' `
            -Headers @{ 'User-Agent' = 'poe2-filter-sync' }
        if ($rel.zipball_url) { $zipUrl = $rel.zipball_url }
    } catch { Write-Warning "No release found, falling back to main.zip: $_" }

    $zip = Join-Path $DestDir 'neversink.zip'
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -Headers @{ 'User-Agent' = 'poe2-filter-sync' }
    Expand-Archive -Path $zip -DestinationPath $DestDir -Force
    Remove-Item $zip

    $style = Get-ChildItem -Path $DestDir -Recurse -Directory |
        Where-Object { $_.Name -like '*CUSTOMSOUNDS*' } | Select-Object -First 1
    if (-not $style) { throw "Could not find a CUSTOMSOUNDS style folder in the NeverSink download." }
    return $style.FullName
}

function Find-SourceFilter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Match
    )
    $hits = @(Get-ChildItem -Path $Dir -Filter *.filter | Where-Object { $_.Name -match [regex]::Escape($Match) })
    if ($hits.Count -eq 0) { throw "No .filter in '$Dir' matching '$Match'." }
    if ($hits.Count -gt 1) { throw "Multiple .filter files match '$Match': $($hits.Name -join ', ')." }
    return $hits[0].FullName
}
Export-ModuleMember -Function Get-NeverSinkFilterDir, Find-SourceFilter
