BeforeAll {
    Import-Module "$PSScriptRoot/../src/InstallSounds.psm1" -Force
    $script:sounds = Join-Path $TestDrive 'sounds'
    New-Item -ItemType Directory -Path $script:sounds | Out-Null
    'audioA' | Set-Content (Join-Path $script:sounds 'veryvaluable.mp3')
    'audioB' | Set-Content (Join-Path $script:sounds 'gay-echo.mp3')
    $script:mapping = [pscustomobject]@{
        FileReplacements  = @{ '6veryvaluable.mp3' = 'veryvaluable.mp3' }
        TargetedOverrides = @([pscustomobject]@{ Identifier='x'; File='gay-echo.mp3'; Volume=300 })
    }
}

Describe 'Install-Sounds' {
    It 'copies file-replacement sounds under the NeverSink name' {
        $poe = Join-Path $TestDrive 'poe'
        Install-Sounds -SoundsDir $script:sounds -Mapping $script:mapping -Poe2Dir $poe
        Get-Content (Join-Path $poe '6veryvaluable.mp3') | Should -Be 'audioA'
    }
    It 'copies targeted-override sounds under their own name and preserves unrelated files' {
        $poe = Join-Path $TestDrive 'poe2'
        New-Item -ItemType Directory -Path $poe | Out-Null
        'keep' | Set-Content (Join-Path $poe 'important.txt')
        Install-Sounds -SoundsDir $script:sounds -Mapping $script:mapping -Poe2Dir $poe
        Get-Content (Join-Path $poe 'gay-echo.mp3') | Should -Be 'audioB'
        Test-Path (Join-Path $poe 'important.txt') | Should -BeTrue
    }
}
