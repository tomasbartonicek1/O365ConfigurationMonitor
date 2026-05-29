. "$PSScriptRoot\Functions\Types.ps1"
. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Functions\Results.ps1"
. "$PSScriptRoot\Functions\Email.ps1"

$failed  = Get-TestsResultsFailed  -ResultsDirectory $appConfig.ResultsDirectory
$changed = Get-TestsResultsChanged -ResultsDirectory $appConfig.ResultsDirectory
Send-DailySummaryEmail -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -FailedTests $failed -ChangedTests $changed
