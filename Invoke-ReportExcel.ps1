$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

Export-FailureReport -ResultsDirectory $appConfig.ResultsDirectory -OutputPath "$($appConfig.ResultsDirectoryReport)\_summary.xlsx"
