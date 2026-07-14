function Publish-Filter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilterPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$FilterId,
        [Parameter(Mandatory)][string]$FilterName,
        [Parameter(Mandatory)][string]$Token,
        [scriptblock]$Invoker
    )
    $text = Get-Content -Path $FilterPath -Raw
    $base = 'https://api.pathofexile.com/item-filter'
    $uri  = if ([string]::IsNullOrEmpty($FilterId)) { $base } else { "$base/$FilterId" }
    $headers = @{ Authorization = "Bearer $Token"; 'Content-Type' = 'application/json'; 'User-Agent' = 'poe2-filter-sync' }
    $body = @{ filter_name = $FilterName; filter = $text; type = 'Normal'; public = $false } | ConvertTo-Json -Depth 5

    if (-not $Invoker) {
        $Invoker = { param($Uri,$Method,$Headers,$Body) Invoke-RestMethod -Uri $Uri -Method $Method -Headers $Headers -Body $Body -UseBasicParsing }
    }
    return & $Invoker -Uri $uri -Method 'Post' -Headers $headers -Body $body
}
Export-ModuleMember -Function Publish-Filter
