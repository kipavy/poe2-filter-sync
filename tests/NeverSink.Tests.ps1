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
}
