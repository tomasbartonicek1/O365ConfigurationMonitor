function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 180
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return & $ScriptBlock
        }
        catch {
            if ($attempt -eq $MaxAttempts) { throw }
            Write-Warning "Attempt $attempt of $MaxAttempts failed: $_. Retrying in $DelaySeconds seconds..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Get-GdapCustomers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig
    )
    return Invoke-WithRetry -ScriptBlock {
        Connect-MgGraph -ClientId $ConnectionConfig.AppId -TenantId $ConnectionConfig.HomeTenantId `
            -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null
        (Get-MgTenantRelationshipDelegatedAdminRelationship -All -ErrorAction Stop |
            Where-Object Status -eq 'Active').Customer |
            Select-Object DisplayName, TenantId -Unique |
            Sort-Object DisplayName
    }
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
