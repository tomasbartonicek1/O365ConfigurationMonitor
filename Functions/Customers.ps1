function Get-GdapCustomers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig
    )
    Connect-MgGraph -ClientId $ConnectionConfig.AppId -TenantId $ConnectionConfig.HomeTenantId `
        -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -NoWelcome | Out-Null
    return (Get-MgTenantRelationshipDelegatedAdminRelationship -All |
        Where-Object Status -eq 'Active').Customer |
        Select-Object DisplayName, TenantId -Unique |
        Sort-Object DisplayName
}

function Test-AccessToCustomersGraph {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        $Customers,
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig
    )
    foreach ($customer in $Customers) {
        try {
            Connect-MgGraph -ClientId $ConnectionConfig.AppId -TenantId $customer.TenantId -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null
            $connected = $true
        }
        catch { $connected = $false }
        Write-Result $connected "Connection to: $($customer.DisplayName) ($($customer.TenantId))" | Out-Null
    }
}

function Test-AccessToCustomersExchange {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        $Customers,
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig
    )
    foreach ($customer in $Customers) {
        try {
            $tenantDomain = Get-TenantDefaultDomain $customer.TenantId
            Connect-ExchangeOnline -AppId $ConnectionConfig.AppId -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
            $connected = $true
        }
        catch { $connected = $false }
        Write-Result $connected "Connection to: $($customer.DisplayName) ($($customer.TenantId))" | Out-Null
    }
}
