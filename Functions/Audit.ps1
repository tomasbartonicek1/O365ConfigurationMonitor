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

function Invoke-TenantAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig,
        [Parameter(Mandatory)]
        $AppConfig,
        [Parameter(Mandatory)]
        $Customers,
        [Parameter(Mandatory)]
        [string[]]$BaseTags,
        [Parameter(Mandatory)]
        [string[]]$ExchangeTags
    )

    $pesterConfig = [PesterConfiguration]@{
        Should = @{ Show = 'Default' }
    }

    $customerCount = $Customers.Count
    $customerIndex = 0

    foreach ($customer in $Customers) {
        $customerIndex++
        Write-Host "[$customerIndex/$customerCount] $($customer.DisplayName)"

        $tenantId = $customer.TenantId

        # Clear all Maester caches
        Clear-MtDnsCache
        Clear-MtGraphCache
        Clear-MtExoCache

        # Connect MS Graph
        try {
            Connect-MgGraph -ClientId $ConnectionConfig.AppId -TenantId $tenantId -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Result $false "(MS Graph) Connection to: $($customer.DisplayName) ($tenantId): MS Graph" | Out-Null
            continue
        }
        Write-Result $true "(MS Graph) Connection to: $($customer.DisplayName) ($tenantId): MS Graph" | Out-Null

        # Connect Exchange Online
        try {
            $tenantDomain = Get-TenantDefaultDomain $tenantId
            Connect-ExchangeOnline -AppId $ConnectionConfig.AppId -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
            $exchangeConnected = $true
        }
        catch { $exchangeConnected = $false }
        Write-Result $exchangeConnected "(Exchange) Connection to: $($customer.DisplayName) ($tenantId): Exchange Online" | Out-Null

        $outputDirectory = "$($AppConfig.ResultsDirectory)\$tenantId"
        if (!(Test-Path $outputDirectory)) {
            New-Item -Path $outputDirectory -ItemType Directory | Out-Null
        }

        $outputFilename = "Test-Results-$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
        $tags = $BaseTags
        if ($exchangeConnected) { $tags += $ExchangeTags }

        try {
            Invoke-Maester -Tag $tags -OutputJsonFile "$outputDirectory\$outputFilename.json" -PesterConfiguration $pesterConfig -SkipGraphConnect -NoLogo
        }
        finally {
            Disconnect-MgGraph | Out-Null
            if ($exchangeConnected) { Disconnect-ExchangeOnline -Confirm:$false | Out-Null }
        }
    }
}
