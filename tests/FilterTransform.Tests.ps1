BeforeAll { Import-Module "$PSScriptRoot/../src/FilterTransform.psm1" -Force }

Describe 'Set-CustomAlertSound' {
    It 'inserts a CustomAlertSound after a matching Show block' {
        $lines = @(
            'Show # $type->currency $tier->d',
            '    BaseType "Chaos Orb"',
            '    PlayAlertSound 1 300'
        )
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->d' -File 'gay-echo.mp3' -Volume 300
        $r.MatchCount | Should -Be 1
        $r.Lines[1] | Should -Be '    CustomAlertSound "gay-echo.mp3" 300'
    }
    It 'replaces an existing CustomAlertSound in the block instead of duplicating' {
        $lines = @(
            'Show # $type->currency $tier->e',
            '    CustomAlertSound "old-existing.mp3" 200'
        )
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->e' -File 'new.mp3' -Volume 300
        ($r.Lines -match 'CustomAlertSound').Count | Should -Be 1
        $r.Lines -join "`n" | Should -Match 'new.mp3'
        $r.Lines -join "`n" | Should -Not -Match 'old-existing.mp3'
    }
    It 'leaves Hide blocks with the same identifier untouched' {
        $lines = @('Hide # $type->currency $tier->hidden', '    BaseType "Scroll"')
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->hidden' -File 'x.mp3' -Volume 300
        $r.MatchCount | Should -Be 0
        $r.Lines | Should -Not -Contain '    CustomAlertSound "x.mp3" 300'
    }
    It 'returns MatchCount 0 when identifier is absent' {
        $lines = @('Show # $type->currency $tier->d', '    BaseType "Chaos Orb"')
        $r = Set-CustomAlertSound -Lines $lines -Identifier '$type->does->not->exist' -File 'x.mp3' -Volume 300
        $r.MatchCount | Should -Be 0
    }
    It 'accepts blank-line elements in Lines without throwing' {
        $lines = @('Show # $type->currency $tier->d', '', '    BaseType "Chaos Orb"')
        { Set-CustomAlertSound -Lines $lines -Identifier '$type->currency $tier->d' -File 'x.mp3' -Volume 300 } |
            Should -Not -Throw
    }
}

Describe 'Assert-AllMappingsMatched' {
    It 'passes when all identifiers matched at least once' {
        { Assert-AllMappingsMatched -MatchReport @{ 'a' = 1; 'b' = 3 } } | Should -Not -Throw
    }
    It 'throws and names every zero-match identifier' {
        { Assert-AllMappingsMatched -MatchReport @{ 'a' = 1; 'b' = 0; 'c' = 0 } } |
            Should -Throw -ExpectedMessage '*b*c*'
    }
}
