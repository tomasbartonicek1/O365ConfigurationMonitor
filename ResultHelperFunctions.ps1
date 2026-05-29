function Get-TestsResultsFailed($resultsDirectory) {
    $failedTests = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($directory in (Get-ChildItem $resultsDirectory -directory)) {
        $latestJsonFile = Get-ChildItem $directory.FullName -Name *.json | Sort-Object CreationTimeUtc | Select-Object -Last 1
        $result = Get-Content ($directory.FullName + "\" + $latestJsonFile) -Raw | ConvertFrom-Json
        $tenantName = $result.TenantName
        foreach ($failedTest in ($result.Tests | Where-Object { $_.Result -eq "Failed" })) {
            $failedTests.Add([PSCustomObject]@{
                'Tenant' = $tenantName
                'Test'   = $failedTest.Name
                'Result' = $failedTest.Result
            })
        }
    }
    return $failedTests
}

function Get-TestsResultsChanged($resultsDirectory) {
    $changedTests = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($directory in (Get-ChildItem $resultsDirectory -directory)) {
        $latestJsonFiles = Get-ChildItem $directory.FullName -Name *.json | Sort-Object CreationTimeUtc | Select-Object -Last 2
        if ($latestJsonFiles.count -ne 2) {
            Write-Warning "Directory $($directory.name) doesn't contain two test results."
        }
        else {
            $priorTest = Get-Content ($directory.FullName + "\" + $latestJsonFiles[0]) -Raw | ConvertFrom-Json
            $newTest = Get-Content ($directory.FullName + "\" + $latestJsonFiles[1]) -Raw | ConvertFrom-Json
            $tenantName = $priorTest.TenantName
            $changes = Compare-MtTestResult -PriorTest $priorTest -NewTest $newTest
            foreach ($change in $changes) {
                $changedTests.Add([PSCustomObject]@{
                    'Tenant'      = $tenantName
                    'Test'        = $change.Name
                    'PriorResult' = $change.PriorState
                    'NewResult'   = $change.NewState
                })
            }
        }
    }
    return $changedTests
}

# Function to write result line by condition and check name
function Write-Result ($condition, $checkName)
{
    $errorDetected = $false
    write-host [ -NoNewline    
    if ($condition) {write-host PASSED -NoNewline -ForegroundColor Green}
    else {
        Write-Host FAILED -NoNewline -ForegroundColor Red
        $errorDetected = $true
    }
    write-host "] $checkName"
    return $errorDetected
}

# Gets tenant info from TenantId
function Get-Tenant {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline)]
        [String]$tenantId
    )    

    $ResolveUri = ("https://graph.microsoft.com/beta/tenantRelationships/findTenantInformationByDomainName(domainName='{0}')" -f $tenantId)
    return Invoke-MgGraphRequest -Method Get -Uri $ResolveUri
}

# Gets tenant display name from TenantID
function Get-TenantDisplayName {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline)]
        [String]$tenantId
    )    

    return (Get-Tenant -TenantId $tenantId).DisplayName
}

# Gets tenant primary domain  from TenantID
function Get-TenantDefaultDomain {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True,ValueFromPipeline)]
        [String]$tenantId
    )    

    return  (Get-Tenant -TenantId $tenantId).defaultDomainName
}

function Test-AccessToCustomersGraph {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphDelegatedAdminRelationshipCustomerParticipant[]]$customers,
        [Parameter(Mandatory=$True)]
        $config
    )  

    foreach($customer in $customers) {
        try {
            Connect-MgGraph -ClientId $config.AppId -TenantId $customer.TenantId -CertificateThumbprint $config.CertificateThumbprint -NoWelcome -ErrorAction Stop  | Out-Null
            $connected = $true
        }
        catch {
            $connected = $false
        }
        Write-Result $connected "Connection to: $($customer.DisplayName) ($($customer.TenantId))" | Out-Null
    }
}

function Test-AccessToCustomersExchange {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphDelegatedAdminRelationshipCustomerParticipant[]]$customers,
        [Parameter(Mandatory=$True)]
        $config
    )  

    foreach($customer in $customers) {
        try {
            $tenantDomain = Get-TenantDefaultDomain $customer.TenantId
            Connect-ExchangeOnline -AppId $config.AppId -CertificateThumbprint $config.CertificateThumbprint -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
            $connected = $true
        }
        catch {
            $connected = $false
        }
        Write-Result $connected "Connection to: $($customer.DisplayName) ($($customer.TenantId))" | Out-Null
    }
}