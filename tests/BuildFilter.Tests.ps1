BeforeAll {
    Import-Module "$PSScriptRoot/../src/BuildFilter.psm1" -Force
    $script:mapping = [pscustomobject]@{
        TargetedOverrides = @(
            [pscustomobject]@{ Identifier = '$type->currency $tier->d'; File = 'gay-echo.mp3'; Volume = 300 },
            [pscustomobject]@{ Identifier = '$type->waystones $tier->waystone_t16'; File = 'TRIPLE_MONSTRE.mp3'; Volume = 300 }
        )
    }
}

Describe 'Build-Filter' {
    It 'applies overrides and writes an output filter' {
        $out = Join-Path $TestDrive 'out'
        $r = Build-Filter -SourceFilterPath "$PSScriptRoot/fixtures/sample.filter" -Mapping $script:mapping -OutDir $out
        Test-Path $r.FilterPath | Should -BeTrue
        (Get-Content $r.FilterPath -Raw) | Should -Match 'gay-echo.mp3'
        (Get-Content $r.FilterPath -Raw) | Should -Match 'TRIPLE_MONSTRE.mp3'
        $r.MatchReport['$type->currency $tier->d'] | Should -Be 1
    }
    It 'throws when an override matches nothing' {
        $bad = [pscustomobject]@{ TargetedOverrides = @(
            [pscustomobject]@{ Identifier = '$type->nope'; File = 'x.mp3'; Volume = 300 }) }
        $out = Join-Path $TestDrive 'out2'
        { Build-Filter -SourceFilterPath "$PSScriptRoot/fixtures/sample.filter" -Mapping $bad -OutDir $out } |
            Should -Throw -ExpectedMessage '*nope*'
    }
}
