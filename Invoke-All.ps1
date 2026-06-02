$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

& "$ScriptRoot\Invoke-UpdateTeamMapping.ps1"
& "$ScriptRoot\Invoke-Audit.ps1"
& "$ScriptRoot\Invoke-ReportExcel.ps1"
& "$ScriptRoot\Invoke-ReportHtml.ps1"
& "$ScriptRoot\Invoke-SharePointUpload.ps1"
#& "$ScriptRoot\Send-DailySummary.ps1"
& "$ScriptRoot\Invoke-CleanupOldReports.ps1"
