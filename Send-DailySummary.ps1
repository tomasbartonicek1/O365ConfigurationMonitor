. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Functions\Results.ps1"
. "$PSScriptRoot\Functions\Email.ps1"

$failed  = Get-TestsResultsFailed  -ResultsDirectory $config.ResultsDirectory
$changed = Get-TestsResultsChanged -ResultsDirectory $config.ResultsDirectory
Send-DailySummaryEmail -Config $config -FailedTests $failed -ChangedTests $changed
