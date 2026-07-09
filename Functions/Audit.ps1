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
        [string[]]$ExchangeTags = @(),
        [string]$TeamMappingFile
    )

    $pesterConfig = [PesterConfiguration]@{
        Should = @{ Show = 'Default' }
    }

    $customerCount = $Customers.Count
    $customerIndex = 0

    foreach ($customer in $Customers) {
        $customerIndex++
        $tenantId = $customer.TenantId
        $exchangeConnected = $false
        Write-Host "[$customerIndex/$customerCount] $($customer.DisplayName) - $(Get-Date -Format 'HH:mm:ss')"

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
            Write-Warning "MS Graph connection error: $_"
            continue
        }
        Write-Result $true "(MS Graph) Connection to: $($customer.DisplayName) ($tenantId): MS Graph" | Out-Null

        # Connect Exchange Online
        try {
            $tenantDomain = Get-TenantDefaultDomain $tenantId
            Connect-ExchangeOnline -AppId $ConnectionConfig.AppId -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
            $exchangeConnected = $true
        }
        catch {
            $exchangeConnected = $false
            Write-Warning "Exchange connection error for $($customer.DisplayName): $_"
        }
        Write-Result $exchangeConnected "(Exchange) Connection to: $($customer.DisplayName) ($tenantId): Exchange Online" | Out-Null

        $outputDirectory = "$($AppConfig.ResultsDirectory)\$tenantId"
        if (!(Test-Path $outputDirectory)) {
            New-Item -Path $outputDirectory -ItemType Directory | Out-Null
        }

        $outputFilename = "Test-Results-$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"
        $tags = $BaseTags
        if ($exchangeConnected) { $tags += $ExchangeTags }

        $jsonPath = "$outputDirectory\$outputFilename.json"
        try {
            Invoke-Maester -Tag $tags -OutputJsonFile $jsonPath -PesterConfiguration $pesterConfig -SkipGraphConnect -NoLogo
        }
        catch {
            Write-Warning "[$customerIndex/$customerCount] Maester failed for $($customer.DisplayName): $_"
        }
        finally {
            try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
            if ($exchangeConnected) {
                try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
            }
        }

        if ($TeamMappingFile -and (Test-Path $TeamMappingFile) -and (Test-Path $jsonPath)) {
            $teamMapping = Get-Content $TeamMappingFile -Raw | ConvertFrom-Json
            $team = $teamMapping.$tenantId
            if ($team) {
                $data = Get-Content $jsonPath -Raw | ConvertFrom-Json
                $data | Add-Member -NotePropertyName 'Team' -NotePropertyValue $team -Force
                $data | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
            }
        }
    }
}
