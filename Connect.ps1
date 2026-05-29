. .\Config.ps1
. .\TestSuite.ps1
. .\ResultHelperFunctions.ps1

# TODO:
# - Auto clean old results

# Get GDAP customers, exclude specified and include extra customers outside of GDAP
Connect-MgGraph -ClientId $config.AppId -TenantId $config.HomeTenantId -CertificateThumbprint $config.CertificateThumbprint -NoWelcome  | Out-Null
$customers = (Get-MgTenantRelationshipDelegatedAdminRelationship -All | Where-Object Status -eq 'Active').Customer
$customers = $customers | Where-Object {$_.TenantId -notin $excludedCustomers} | Select-Object DisplayName, TenantId -Unique | Sort-Object DisplayName
$customers += $includedCustomers

$pesterConfig = [PesterConfiguration]@{
    Should = @{
        Show = 'Default'
    }
}

$customerCount = $customers.Count
$customerIndex = 0

# =============================
# Run for all tenants
foreach ($customer in $customers) {
    $customerIndex++
    Write-Host "[$customerIndex/$customerCount] $($customer.DisplayName)"

    ####
    # Connect MS Graph
    $tenantId = $customer.TenantId
    try {
        Connect-MgGraph -ClientId $config.AppId -TenantId $tenantId -CertificateThumbprint $config.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Result $false "(MS Graph) Connection to: $($customer.DisplayName) ($($customer.TenantId)): MS Graph" | Out-Null
        # If unable to connect to customer's MS Graph skip to other customer
        continue
    }
    Write-Result $true "(MS Graph) Connection to: $($customer.DisplayName) ($($customer.TenantId)): MS Graph" | Out-Null

    ####
    # Try to Connect Exchange Online
    try {
        $tenantDomain = Get-TenantDefaultDomain $customer.TenantId
        Connect-ExchangeOnline -AppId $config.AppId -CertificateThumbprint $config.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
        $exchangeConnected = $true
    }
    catch {
        $exchangeConnected = $false
    }
    Write-Result $exchangeConnected "(Exchange) Connection to: $($customer.DisplayName) ($($customer.TenantId)): Exchange Online" | Out-Null

    $outputDirectory = "$($config.ResultsDirectory)\$tenantId"
    if (!(Test-Path $outputDirectory)) {
        Write-Verbose "Creating directory: $outputDirectory"
        New-Item -Path $outputDirectory -ItemType Directory | Out-Null
    }

    $outputFilename = "Test-Results-$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))"

    $tags = $baseTags
    if ($exchangeConnected) {
        $tags += $exchangeTags
    }

    try {
        Invoke-Maester -Tag $tags -OutputJsonFile "$outputDirectory\$outputFilename.json" -PesterConfiguration $pesterConfig -SkipGraphConnect
    }
    finally {
        Disconnect-MgGraph | Out-Null
        if ($exchangeConnected) { Disconnect-ExchangeOnline -Confirm:$false }
    }
}

# Get-TestsResultsFailed -resultsDirectory $config.ResultsDirectory
# Get-TestsResultsChanged -resultsDirectory $config.ResultsDirectory
# Get-TestsResultsFailed -resultsDirectory $config.ResultsDirectory | Export-Csv -Path "failures.csv" -Encoding utf8BOM
