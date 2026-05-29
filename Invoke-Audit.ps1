. "$PSScriptRoot\Functions\Types.ps1"
. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\TestSuite.ps1"
. "$PSScriptRoot\Functions\Audit.ps1"
. "$PSScriptRoot\Functions\Customers.ps1"

$customers  = Get-GdapCustomers -ConnectionConfig $connectionConfig
$customers  = $customers | Where-Object { $_.TenantId -notin $appConfig.ExcludedCustomers }
$customers += $appConfig.AdditionalCustomers

Invoke-TenantAudit -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -Customers $customers -BaseTags $baseTags -ExchangeTags $exchangeTags
