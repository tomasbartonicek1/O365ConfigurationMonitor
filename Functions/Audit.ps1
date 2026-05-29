function Write-Result {
    param(
        [bool]$Condition,
        [string]$CheckName
    )
    $errorDetected = $false
    Write-Host '[' -NoNewline
    if ($Condition) { Write-Host 'PASSED' -NoNewline -ForegroundColor Green }
    else {
        Write-Host 'FAILED' -NoNewline -ForegroundColor Red
        $errorDetected = $true
    }
    Write-Host "] $CheckName"
    return $errorDetected
}

function Get-Tenant {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$TenantId
    )
    $uri = "https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByDomainName(domainName='{0}')" -f $TenantId
    return Invoke-MgGraphRequest -Method Get -Uri $uri
}

function Get-TenantDisplayName {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$TenantId
    )
    return (Get-Tenant -TenantId $TenantId).DisplayName
}

function Get-TenantDefaultDomain {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$TenantId
    )
    return (Get-Tenant -TenantId $TenantId).defaultDomainName
}

function Test-AccessToCustomersGraph {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        $Customers,
        [Parameter(Mandatory)]
        $Config
    )
    foreach ($customer in $Customers) {
        try {
            Connect-MgGraph -ClientId $Config.AppId -TenantId $customer.TenantId -CertificateThumbprint $Config.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null
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
        $Config
    )
    foreach ($customer in $Customers) {
        try {
            $tenantDomain = Get-TenantDefaultDomain $customer.TenantId
            Connect-ExchangeOnline -AppId $Config.AppId -CertificateThumbprint $Config.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
            $connected = $true
        }
        catch { $connected = $false }
        Write-Result $connected "Connection to: $($customer.DisplayName) ($($customer.TenantId))" | Out-Null
    }
}

function Invoke-TenantAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,
        [Parameter(Mandatory)]
        [string[]]$BaseTags,
        [Parameter(Mandatory)]
        [string[]]$ExchangeTags,
        [string[]]$ExcludedCustomers = @(),
        [PSCustomObject[]]$AdditionalCustomers = @()
    )

    # TODO: Auto clean old results

    $pesterConfig = [PesterConfiguration]@{
        Should = @{ Show = 'Default' }
    }

    # Get GDAP customers, apply exclusions and additions
    Connect-MgGraph -ClientId $Config.AppId -TenantId $Config.HomeTenantId -CertificateThumbprint $Config.CertificateThumbprint -NoWelcome | Out-Null
    $customers = (Get-MgTenantRelationshipDelegatedAdminRelationship -All | Where-Object Status -eq 'Active').Customer
    $customers = $customers | Where-Object { $_.TenantId -notin $ExcludedCustomers } | Select-Object DisplayName, TenantId -Unique | Sort-Object DisplayName
    $customers += $AdditionalCustomers

    $customerCount = $customers.Count
    $customerIndex = 0

    foreach ($customer in $customers) {
        $customerIndex++
        Write-Host "[$customerIndex/$customerCount] $($customer.DisplayName)"

        $tenantId = $customer.TenantId

        # Connect MS Graph
        try {
            Connect-MgGraph -ClientId $Config.AppId -TenantId $tenantId -CertificateThumbprint $Config.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Result $false "(MS Graph) Connection to: $($customer.DisplayName) ($tenantId): MS Graph" | Out-Null
            continue
        }
        Write-Result $true "(MS Graph) Connection to: $($customer.DisplayName) ($tenantId): MS Graph" | Out-Null

        # Connect Exchange Online
        try {
            $tenantDomain = Get-TenantDefaultDomain $tenantId
            Connect-ExchangeOnline -AppId $Config.AppId -CertificateThumbprint $Config.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
            $exchangeConnected = $true
        }
        catch { $exchangeConnected = $false }
        Write-Result $exchangeConnected "(Exchange) Connection to: $($customer.DisplayName) ($tenantId): Exchange Online" | Out-Null

        $outputDirectory = "$($Config.ResultsDirectory)\$tenantId"
        if (!(Test-Path $outputDirectory)) {
            New-Item -Path $outputDirectory -ItemType Directory | Out-Null
        }

        $outputFilename = "Test-Results-$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
        $tags = $BaseTags
        if ($exchangeConnected) { $tags += $ExchangeTags }

        try {
            Invoke-Maester -Tag $tags -OutputJsonFile "$outputDirectory\$outputFilename.json" -PesterConfiguration $pesterConfig -SkipGraphConnect
        }
        finally {
            Disconnect-MgGraph | Out-Null
            if ($exchangeConnected) { Disconnect-ExchangeOnline -Confirm:$false }
        }
    }
}
