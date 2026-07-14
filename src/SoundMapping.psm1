function Get-SoundMapping {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$SoundsDir
    )
    if (-not (Test-Path $Path)) { throw "Config not found: $Path" }
    $raw = Get-Content -Path $Path -Raw
    try { $json = $raw | ConvertFrom-Json } catch { throw "Invalid JSON in ${Path}: $_" }

    $result = [pscustomobject]@{
        PoeFilterId       = [string]$json.poeFilterId
        PoeFilterName     = [string]$json.poeFilterName
        SourceFilterMatch = [string]$json.sourceFilterMatch
        FollowUrls        = @($json.followUrls)
        FileReplacements  = @{}
        TargetedOverrides = @()
    }
    foreach ($p in $json.fileReplacements.PSObject.Properties) {
        $result.FileReplacements[$p.Name] = [string]$p.Value
    }
    $result.TargetedOverrides = @(
        foreach ($o in $json.targetedOverrides) {
            [pscustomobject]@{ Identifier = [string]$o.identifier; File = [string]$o.file; Volume = [int]$o.volume }
        }
    )

    # every referenced sound must exist
    $referenced = @($result.FileReplacements.Values) + @($result.TargetedOverrides.File) | Sort-Object -Unique
    foreach ($f in $referenced) {
        if (-not (Test-Path (Join-Path $SoundsDir $f))) {
            throw "Referenced sound file missing from '$SoundsDir': $f"
        }
    }
    return $result
}
Export-ModuleMember -Function Get-SoundMapping
