Import-Module "$PSScriptRoot/FilterTransform.psm1" -Force

function Build-Filter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceFilterPath,
        [Parameter(Mandatory)][object]$Mapping,
        [Parameter(Mandatory)][string]$OutDir
    )
    if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
    $lines = Get-Content -Path $SourceFilterPath
    $report = @{}
    foreach ($o in $Mapping.TargetedOverrides) {
        $res = Set-CustomAlertSound -Lines $lines -Identifier $o.Identifier -File $o.File -Volume $o.Volume
        $lines = $res.Lines
        $report[$o.Identifier] = $res.MatchCount
    }
    Assert-AllMappingsMatched -MatchReport $report
    $outFile = Join-Path $OutDir 'filter.filter'
    Set-Content -Path $outFile -Value $lines -Force
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

    $results = [System.Collections.Generic.List[object]]::new()
    $aggregate = @{}
    foreach ($o in $Mapping.TargetedOverrides) { $aggregate[$o.Identifier] = 0 }

    foreach ($sourcePath in $SourceFilterPaths) {
        $name = Split-Path $sourcePath -Leaf
        $lines = Get-Content -Path $sourcePath
        $report = @{}
        foreach ($o in $Mapping.TargetedOverrides) {
            $res = Set-CustomAlertSound -Lines $lines -Identifier $o.Identifier -File $o.File -Volume $o.Volume
            $lines = $res.Lines
            $report[$o.Identifier] = $res.MatchCount
            $aggregate[$o.Identifier] += $res.MatchCount
        }
        $outFile = Join-Path $OutDir $name
        Set-Content -Path $outFile -Value $lines -Force
        $results.Add([pscustomobject]@{ Name = $name; FilterPath = $outFile; MatchReport = $report })
    }

    Assert-AllMappingsMatched -MatchReport $aggregate
    return $results.ToArray()
}

Export-ModuleMember -Function Build-Filter, Build-AllFilters
