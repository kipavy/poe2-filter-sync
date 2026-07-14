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
    It 'preserves non-ASCII UTF-8 characters and writes LF with no BOM' {
        # NeverSink filters contain UTF-8 chars (e.g. "Mórrigan's Insight"). PS 5.1's
        # ANSI default Get/Set-Content corrupts them per machine — the build must be byte-faithful.
        $srcDir = Join-Path $TestDrive 'enc'; New-Item -ItemType Directory -Path $srcDir | Out-Null
        $src = Join-Path $srcDir 'src.filter'
        # Build the 'ó' (U+00F3) from its code point so this test does not depend on how
        # PowerShell 5.1 decodes THIS .ps1 file (the very bug under test).
        $oAcute = [char]0x00F3
        $content = "Show # `$type->currency `$tier->d !x`r`n    BaseType `"M${oAcute}rrigan's Insight`"`r`n"
        [System.IO.File]::WriteAllText($src, $content, (New-Object System.Text.UTF8Encoding($false)))
        $out = Join-Path $TestDrive 'encout'
        $m = [pscustomobject]@{ TargetedOverrides = @(
            [pscustomobject]@{ Identifier = '$type->currency $tier->d'; File = 'gay-echo.mp3'; Volume = 300 }) }
        $r = Build-Filter -SourceFilterPath $src -Mapping $m -OutDir $out
        $bytes = [System.IO.File]::ReadAllBytes($r.FilterPath)
        # UTF-8 'ó' is 0xC3 0xB3 — must survive intact
        $hasOAcute = $false
        for ($i = 0; $i -lt $bytes.Length - 1; $i++) { if ($bytes[$i] -eq 0xC3 -and $bytes[$i+1] -eq 0xB3) { $hasOAcute = $true; break } }
        $hasOAcute | Should -BeTrue
        # No BOM (must not start with EF BB BF)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
        # No CR bytes (LF-only)
        ($bytes -contains 0x0D) | Should -BeFalse
    }
}
