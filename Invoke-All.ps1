. "$PSScriptRoot\Functions\Types.ps1"
. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\TestSuite.ps1"
. "$PSScriptRoot\Functions\Audit.ps1"
. "$PSScriptRoot\Functions\Customers.ps1"
. "$PSScriptRoot\Functions\Results.ps1"
. "$PSScriptRoot\Functions\Email.ps1"

# 1. Audit všech zákazníků
$customers  = Get-GdapCustomers -ConnectionConfig $connectionConfig
$customers  = $customers | Where-Object { $_.TenantId -notin $appConfig.ExcludedCustomers }
$customers += $appConfig.AdditionalCustomers

Invoke-TenantAudit -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -Customers $customers -BaseTags $baseTags -ExchangeTags $exchangeTags

# 2. Export reportu selhání do CSV
Export-FailureReport -ResultsDirectory $appConfig.ResultsDirectory

# 2.5 Generování HTML reportů pro každého tenanta
& "$PSScriptRoot\Invoke-HtmlReport.ps1"

# 2.7 Nahrání HTML reportů na SharePoint
& "$PSScriptRoot\Invoke-SharePointUpload.ps1"

# 3. Odeslání denního souhrnu e-mailem
$failed  = Get-TestsResultsFailed  -ResultsDirectory $appConfig.ResultsDirectory
$changed = Get-TestsResultsChanged -ResultsDirectory $appConfig.ResultsDirectory
Send-DailySummaryEmail -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -FailedTests $failed -ChangedTests $changed
