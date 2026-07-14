BeforeAll {
    Import-Module "$PSScriptRoot/../src/BuildFilter.psm1" -Force
}

Describe 'Build-AllFilters' {
    BeforeEach {
        $script:srcDir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:srcDir | Out-Null

        $script:source1 = Join-Path $script:srcDir 'source1.filter'
        Set-Content -Path $script:source1 -Value @(
            'Show # $type->a $tier->x',
            '    BaseType "Chaos Orb"',
            '',
            'Show # $type->a $tier->y',
            '    BaseType "Exalted Orb"'
        )

        $script:source2 = Join-Path $script:srcDir 'source2.filter'
        Set-Content -Path $script:source2 -Value @(
            'Show # $type->a $tier->x',
            '    BaseType "Chaos Orb"'
        )

        $script:mapping = [pscustomobject]@{
            TargetedOverrides = @(
                [pscustomobject]@{ Identifier = '$type->a $tier->x'; File = 'ax.mp3'; Volume = 300 },
                [pscustomobject]@{ Identifier = '$type->a $tier->y'; File = 'ay.mp3'; Volume = 300 }
            )
        }
    }

    It 'builds all variants, writing each with the original filename, when every override matches somewhere' {
        $out = Join-Path $TestDrive 'out'
        $results = Build-AllFilters -SourceFilterPaths @($script:source1, $script:source2) -Mapping $script:mapping -OutDir $out

        $results.Count | Should -Be 2

        $r1 = $results | Where-Object { $_.Name -eq 'source1.filter' }
        $r2 = $results | Where-Object { $_.Name -eq 'source2.filter' }

        Test-Path $r1.FilterPath | Should -BeTrue
        Test-Path $r2.FilterPath | Should -BeTrue
        (Split-Path $r1.FilterPath -Leaf) | Should -Be 'source1.filter'
        (Split-Path $r2.FilterPath -Leaf) | Should -Be 'source2.filter'

        (Get-Content $r1.FilterPath -Raw) | Should -Match 'ax.mp3'
        (Get-Content $r1.FilterPath -Raw) | Should -Match 'ay.mp3'
        (Get-Content $r2.FilterPath -Raw) | Should -Match 'ax.mp3'
        (Get-Content $r2.FilterPath -Raw) | Should -Not -Match 'ay.mp3'
    }

    It 'does not throw when an override matches in only one of several variants (aggregate OK)' {
        $out = Join-Path $TestDrive 'out'
        { Build-AllFilters -SourceFilterPaths @($script:source1, $script:source2) -Mapping $script:mapping -OutDir $out } |
            Should -Not -Throw
    }

    It 'throws naming an identifier that matches in NO variant at all' {
        $badMapping = [pscustomobject]@{
            TargetedOverrides = @(
                [pscustomobject]@{ Identifier = '$type->a $tier->x'; File = 'ax.mp3'; Volume = 300 },
                [pscustomobject]@{ Identifier = '$type->a $tier->z'; File = 'az.mp3'; Volume = 300 }
            )
        }
        $out = Join-Path $TestDrive 'out3'
        { Build-AllFilters -SourceFilterPaths @($script:source1, $script:source2) -Mapping $badMapping -OutDir $out } |
            Should -Throw -ExpectedMessage '*z*'
    }
}
