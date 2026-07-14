function Set-CustomAlertSound {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Lines,
        [Parameter(Mandatory)][string]$Identifier,
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][int]$Volume
    )
    $escaped        = [regex]::Escape($Identifier)
    $reIdentifier   = [regex]::new(".*$escaped\s*$")
    $reHide         = [regex]::new('^\s*Hide')
    $reCustomAlert  = [regex]::new('^\s*CustomAlertSound')
    $reSection      = [regex]::new('^\s*(Show|Hide)')
    $soundLine      = "    CustomAlertSound `"$File`" $Volume"

    $out = [System.Collections.Generic.List[string]]::new()
    $matchCount = 0
    $inTarget = $false
    $inserted = $false

    foreach ($line in $Lines) {
        if ($reIdentifier.IsMatch($line)) {
            if ($reHide.IsMatch($line)) { $out.Add($line); $inTarget = $false; continue }
            $out.Add($line)
            $out.Add($soundLine)
            $matchCount++
            $inTarget = $true
            $inserted = $true
            continue
        }
        if ($inTarget -and $reCustomAlert.IsMatch($line)) {
            # our inserted line is already present; drop the original CustomAlertSound
            continue
        }
        if ($inTarget -and $reSection.IsMatch($line)) {
            $inTarget = $false; $inserted = $false
        }
        $out.Add($line)
    }
    return [pscustomobject]@{ Lines = $out.ToArray(); MatchCount = $matchCount }
}
Export-ModuleMember -Function Set-CustomAlertSound
