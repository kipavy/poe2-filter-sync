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
Export-ModuleMember -Function Build-Filter
