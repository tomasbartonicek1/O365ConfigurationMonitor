$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$failed  = Get-TestsResultsFailed  -ResultsDirectory $appConfig.ResultsDirectory
$changed = Get-TestsResultsChanged -ResultsDirectory $appConfig.ResultsDirectory
Send-DailySummaryEmail -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -FailedTests $failed -ChangedTests $changed
