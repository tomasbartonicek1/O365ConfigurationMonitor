. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\TestSuite.ps1"
. "$PSScriptRoot\Functions\Audit.ps1"

Invoke-TenantAudit `
    -Config             $config `
    -BaseTags           $baseTags `
    -ExchangeTags       $exchangeTags `
    -ExcludedCustomers  $excludedCustomers `
    -AdditionalCustomers $includedCustomers
