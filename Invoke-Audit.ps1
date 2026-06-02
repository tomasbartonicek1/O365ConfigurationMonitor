$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$customers  = Get-GdapCustomers -ConnectionConfig $connectionConfig
$customers  = $customers | Where-Object { $_.TenantId -notin $appConfig.ExcludedCustomers }
$customers += $appConfig.AdditionalCustomers

Invoke-TenantAudit -ConnectionConfig $connectionConfig -AppConfig $appConfig `
    -Customers $customers -BaseTags $baseTags -ExchangeTags $exchangeTags `
    -TeamMappingFile $appConfig.TeamMappingFile
