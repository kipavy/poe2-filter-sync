BeforeAll {
    Import-Module "$PSScriptRoot/../src/SoundMapping.psm1" -Force
    $script:soundsDir = Join-Path $TestDrive 'sounds'
    New-Item -ItemType Directory -Path $script:soundsDir | Out-Null
    foreach ($f in 'myA.mp3','myB.mp3') {
        New-Item -ItemType File -Path (Join-Path $script:soundsDir $f) | Out-Null
    }

    $script:cfgPath = Join-Path $TestDrive 'sound-mapping.json'
    $fixture = [ordered]@{
        poeFilterId       = ''
        poeFilterName     = 'Test Filter'
        sourceFilterMatch = '3-STRICT'
        followUrls        = @('https://example.test/f')
        fileReplacements  = [ordered]@{
            '1maybevaluable.mp3' = 'myA.mp3'
        }
        targetedOverrides = @(
            [ordered]@{
                identifier = '$type->currency $tier->d'
                file       = 'myB.mp3'
                volume     = 250
            }
        )
    }
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -Path $script:cfgPath
}

Describe 'Get-SoundMapping' {
    It 'parses metadata and sections' {
        $m = Get-SoundMapping -Path $script:cfgPath -SoundsDir $script:soundsDir
        $m.PoeFilterName | Should -Be 'Test Filter'
        $m.SourceFilterMatch | Should -Be '3-STRICT'
        $m.FollowUrls[0] | Should -Be 'https://example.test/f'
        $m.FollowUrls.Count | Should -Be 1
        $m.TargetedOverrides.Count | Should -Be 1
        $m.TargetedOverrides[0].Volume | Should -Be 250
        $m.FileReplacements['1maybevaluable.mp3'] | Should -Be 'myA.mp3'
    }
    It 'throws when a referenced sound file is missing' {
        Remove-Item (Join-Path $script:soundsDir 'myB.mp3')
        { Get-SoundMapping -Path $script:cfgPath -SoundsDir $script:soundsDir } |
            Should -Throw -ExpectedMessage '*myB.mp3*'
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
