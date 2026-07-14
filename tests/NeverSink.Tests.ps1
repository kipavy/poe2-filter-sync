BeforeAll { Import-Module "$PSScriptRoot/../src/NeverSink.psm1" -Force }

Describe 'Find-SourceFilter' {
    BeforeEach {
        $script:dir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:dir | Out-Null
    }
    It 'returns the single filter matching the strictness token' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'NeverSink 1-REGULAR.filter') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir 'NeverSink 4-STRICT.filter') | Out-Null
        (Find-SourceFilter -Dir $script:dir -Match 'STRICT') | Should -Match 'STRICT'
    }
    It 'throws when no filter matches' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'NeverSink 1-REGULAR.filter') | Out-Null
        { Find-SourceFilter -Dir $script:dir -Match 'STRICT' } | Should -Throw
    }
    It 'throws when multiple filters match' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'a-STRICT.filter') | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir 'b-STRICT.filter') | Out-Null
        { Find-SourceFilter -Dir $script:dir -Match 'STRICT' } | Should -Throw
    }
    It 'throws on ambiguous STRICT token but resolves with the full strictness tier name' {
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 2-SEMI-STRICT (customsounds) .filter") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 3-STRICT (customsounds) .filter") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 4-VERY-STRICT (customsounds) .filter") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 5-UBER-STRICT (customsounds) .filter") | Out-Null
        { Find-SourceFilter -Dir $script:dir -Match 'STRICT' } | Should -Throw
        (Find-SourceFilter -Dir $script:dir -Match '3-STRICT') | Should -Match '3-STRICT'
    }
}

Describe 'Get-AllSourceFilters' {
    BeforeEach {
        $script:dir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:dir | Out-Null
    }
    It 'returns all .filter files in the dir, sorted by name' {
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 3-STRICT (customsounds) .filter") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 0-SOFT (customsounds) .filter") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir "NeverSink's filter 2 - 1-REGULAR (customsounds) .filter") | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:dir 'readme.txt') | Out-Null
        $result = Get-AllSourceFilters -Dir $script:dir
        $result.Count | Should -Be 3
        ($result | ForEach-Object { Split-Path $_ -Leaf }) | Should -Be @(
            "NeverSink's filter 2 - 0-SOFT (customsounds) .filter",
            "NeverSink's filter 2 - 1-REGULAR (customsounds) .filter",
            "NeverSink's filter 2 - 3-STRICT (customsounds) .filter"
        )
    }
    It 'throws when the dir has no .filter files' {
        New-Item -ItemType File -Path (Join-Path $script:dir 'readme.txt') | Out-Null
        { Get-AllSourceFilters -Dir $script:dir } | Should -Throw
    }
}
