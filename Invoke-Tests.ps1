#requires -Version 5.1
$pester5 = Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge [version]'5.0' }
if (-not $pester5) {
    Install-Module Pester -MinimumVersion 5.0 -Force -Scope CurrentUser -SkipPublisherCheck
}
Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester -Path "$PSScriptRoot/tests" -Output Detailed
