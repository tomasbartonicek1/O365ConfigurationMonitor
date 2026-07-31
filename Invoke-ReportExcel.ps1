$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$freshnessWindow = if ($appConfig.ResultFreshnessWindowHours) { $appConfig.ResultFreshnessWindowHours } else { 24 }
Export-FailureReport -ResultsDirectory $appConfig.ResultsDirectory -OutputPath "$($appConfig.ResultsDirectoryReport)\_summary.xlsx" -FreshnessWindowHours $freshnessWindow
