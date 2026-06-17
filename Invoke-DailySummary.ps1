$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$changed = Get-TestsResultsChanged -ResultsDirectory $appConfig.ResultsDirectory
Send-DailySummaryEmail -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -ChangedTests $changed
