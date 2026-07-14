BeforeAll {
    Import-Module "$PSScriptRoot/../src/SoundMapping.psm1" -Force
    $script:soundsDir = Join-Path $TestDrive 'sounds'
    New-Item -ItemType Directory -Path $script:soundsDir | Out-Null
    foreach ($f in '1maybevaluable.mp3','2currency.mp3','3uniques.mp3','4maps.mp3','5highmaps.mp3','6veryvaluable.mp3','gay-echo.mp3','TRIPLE_MONSTRE.mp3') {
        New-Item -ItemType File -Path (Join-Path $script:soundsDir $f) | Out-Null
    }
    $script:cfgPath = Join-Path $TestDrive 'sound-mapping.json'
    Copy-Item "$PSScriptRoot/../config/sound-mapping.json" $script:cfgPath
}

Describe 'Get-SoundMapping' {
    It 'parses metadata and sections' {
        $m = Get-SoundMapping -Path $script:cfgPath -SoundsDir $script:soundsDir
        $m.PoeFilterName | Should -Be 'NeverSink + custom sounds'
        $m.SourceFilterMatch | Should -Be 'STRICT'
        $m.TargetedOverrides.Count | Should -Be 2
        $m.TargetedOverrides[0].Volume | Should -Be 300
    }
    It 'throws when a referenced sound file is missing' {
        Remove-Item (Join-Path $script:soundsDir 'gay-echo.mp3')
        { Get-SoundMapping -Path $script:cfgPath -SoundsDir $script:soundsDir } |
            Should -Throw -ExpectedMessage '*gay-echo.mp3*'
    }
    It 'throws when the config file path does not exist' {
        { Get-SoundMapping -Path (Join-Path $TestDrive 'nonexistent.json') -SoundsDir $script:soundsDir } |
            Should -Throw -ExpectedMessage '*Config not found*'
    }
    It 'throws when the config file contains invalid JSON' {
        $invalidPath = Join-Path $TestDrive 'invalid.json'
        Set-Content -Path $invalidPath -Value '{ not valid json'
        { Get-SoundMapping -Path $invalidPath -SoundsDir $script:soundsDir } |
            Should -Throw -ExpectedMessage '*Invalid JSON*'
    }
}
