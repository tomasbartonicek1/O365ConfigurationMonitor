. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\TestSuite.ps1"
. "$PSScriptRoot\Functions\Audit.ps1"
. "$PSScriptRoot\Functions\Results.ps1"
. "$PSScriptRoot\Functions\Email.ps1"

# 1. Audit všech zákazníků
Invoke-TenantAudit `
    -Config              $config `
    -BaseTags            $baseTags `
    -ExchangeTags        $exchangeTags `
    -ExcludedCustomers   $excludedCustomers `
    -AdditionalCustomers $includedCustomers

# 2. Export reportu selhání do CSV
Export-FailureReport -ResultsDirectory $config.ResultsDirectory

# 3. Odeslání denního souhrnu e-mailem
$failed  = Get-TestsResultsFailed  -ResultsDirectory $config.ResultsDirectory
$changed = Get-TestsResultsChanged -ResultsDirectory $config.ResultsDirectory
Send-DailySummaryEmail -Config $config -FailedTests $failed -ChangedTests $changed
