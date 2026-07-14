BeforeAll { Import-Module "$PSScriptRoot/../src/PublishFilter.psm1" -Force }

Describe 'Publish-Filter' {
    It 'POSTs to the id-specific endpoint with a bearer token and filter body' {
        $captured = $null
        $invoker = { param($Uri,$Method,$Headers,$Body) $script:captured = @{ Uri=$Uri; Method=$Method; Headers=$Headers; Body=$Body }; @{ ok = $true } }
        $f = Join-Path $TestDrive 'f.filter'; 'Show' | Set-Content $f
        Publish-Filter -FilterPath $f -FilterId 'abc123' -FilterName 'N' -Token 'TKN' -Invoker $invoker | Out-Null
        $script:captured.Uri | Should -Be 'https://api.pathofexile.com/item-filter/abc123'
        $script:captured.Method | Should -Be 'Post'
        $script:captured.Headers.Authorization | Should -Be 'Bearer TKN'
        ($script:captured.Body | ConvertFrom-Json).filter | Should -Match 'Show'
    }
    It 'POSTs to the create endpoint when FilterId is empty' {
        $invoker = { param($Uri,$Method,$Headers,$Body) $script:u = $Uri; @{} }
        $f = Join-Path $TestDrive 'f.filter'; 'Show' | Set-Content $f
        Publish-Filter -FilterPath $f -FilterId '' -FilterName 'N' -Token 'TKN' -Invoker $invoker | Out-Null
        $script:u | Should -Be 'https://api.pathofexile.com/item-filter'
    }
}
