$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$freshnessWindow = if ($appConfig.ResultFreshnessWindowHours) { $appConfig.ResultFreshnessWindowHours } else { 24 }
$changed = Get-TestsResultsChanged -ResultsDirectory $appConfig.ResultsDirectory -FreshnessWindowHours $freshnessWindow
Send-DailySummaryEmail -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -ChangedTests $changed
