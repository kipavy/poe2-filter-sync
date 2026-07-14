Import-Module "$PSScriptRoot/FilterTransform.psm1" -Force

# Read a filter file as UTF-8 regardless of the machine's default code page, so
# non-ASCII characters in the NeverSink filter (e.g. "Mórrigan's Insight") are not
# corrupted. Windows PowerShell 5.1's Get-Content/Set-Content default to the ANSI
# code page, which mangles UTF-8 bytes differently per system and breaks parsing.
function Read-FilterLines {
    param([Parameter(Mandatory)][string]$Path)
    $full = (Resolve-Path -LiteralPath $Path).Path
    $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    return ($text -split "\r?\n")
}

# Write the built filter as UTF-8 WITHOUT BOM and with LF line endings, matching
# NeverSink's own encoding byte-for-byte (plus our inserted lines). A BOM or ANSI
# re-encoding here is what corrupts the filter for the end user.
function Write-FilterFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, ($Lines -join "`n"), $utf8NoBom)
}

function Build-Filter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceFilterPath,
        [Parameter(Mandatory)][object]$Mapping,
        [Parameter(Mandatory)][string]$OutDir
    )
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $OutDir = (Resolve-Path -LiteralPath $OutDir).Path
    $lines = Read-FilterLines -Path $SourceFilterPath
    $report = @{}
    foreach ($o in $Mapping.TargetedOverrides) {
        $res = Set-CustomAlertSound -Lines $lines -Identifier $o.Identifier -File $o.File -Volume $o.Volume
        $lines = $res.Lines
        $report[$o.Identifier] = $res.MatchCount
    }
    Assert-AllMappingsMatched -MatchReport $report
    $outFile = Join-Path $OutDir 'filter.filter'
    Write-FilterFile -Path $outFile -Lines $lines
    return [pscustomobject]@{ FilterPath = $outFile; MatchReport = $report }
}
function Build-AllFilters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$SourceFilterPaths,
        [Parameter(Mandatory)][object]$Mapping,
        [Parameter(Mandatory)][string]$OutDir
    )
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $OutDir = (Resolve-Path -LiteralPath $OutDir).Path

    $results = [System.Collections.Generic.List[object]]::new()
    $aggregate = @{}
    foreach ($o in $Mapping.TargetedOverrides) { $aggregate[$o.Identifier] = 0 }

    foreach ($sourcePath in $SourceFilterPaths) {
        $name = Split-Path $sourcePath -Leaf
        $lines = Read-FilterLines -Path $sourcePath
        $report = @{}
        foreach ($o in $Mapping.TargetedOverrides) {
            $res = Set-CustomAlertSound -Lines $lines -Identifier $o.Identifier -File $o.File -Volume $o.Volume
            $lines = $res.Lines
            $report[$o.Identifier] = $res.MatchCount
            $aggregate[$o.Identifier] += $res.MatchCount
        }
        $outFile = Join-Path $OutDir $name
        Write-FilterFile -Path $outFile -Lines $lines
        $results.Add([pscustomobject]@{ Name = $name; FilterPath = $outFile; MatchReport = $report })
    }

    Assert-AllMappingsMatched -MatchReport $aggregate
    return ,$results.ToArray()
}

Export-ModuleMember -Function Build-Filter, Build-AllFilters
