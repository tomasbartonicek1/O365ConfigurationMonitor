function Get-FreshTenantResults {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsDirectory,
        [double]$FreshnessWindowHours = 24
    )

    # Collect the latest result per tenant, dating each by the timestamp embedded in
    # its filename (Test-Results-yyyy-MM-dd-HHmmss.json) - the authoritative audit time,
    # the same source Invoke-CleanupOldReports.ps1 uses (robust to file copies).
    $tenants = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($directory in (Get-ChildItem $ResultsDirectory -Directory)) {
        $dated = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($file in (Get-ChildItem $directory.FullName -Filter 'Test-Results-*.json')) {
            $dateStr = $file.BaseName -replace '^Test-Results-', ''
            try {
                $fileDate = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd-HHmmss',
                    [System.Globalization.CultureInfo]::InvariantCulture)
            } catch {
                Write-Warning "Cannot parse date from filename: $($file.Name), skipping."
                continue
            }
            $dated.Add([PSCustomObject]@{ File = $file; Date = $fileDate })
        }
        if ($dated.Count -eq 0) {
            Write-Warning "No parseable result files in $($directory.Name), skipping."
            continue
        }
        $sorted = @($dated | Sort-Object Date)   # ascending by audit date
        $tenants.Add([PSCustomObject]@{
            TenantId   = $directory.Name
            Directory  = $directory
            LatestFile = $sorted[-1].File
            LatestDate = $sorted[-1].Date
            Files      = @($sorted.File)
        })
    }

    if ($tenants.Count -eq 0) {
        return @()
    }

    # Anchor freshness to the most recent audit across all tenants (self-calibrating:
    # a skipped audit run doesn't empty the report - all tenants stay near the shared
    # anchor). A tenant removed from GDAP stops getting new results and ages past the
    # window, so it drops out of reports and the daily email.
    $anchor = ($tenants.LatestDate | Measure-Object -Maximum).Maximum
    $cutoff = $anchor.AddHours(-$FreshnessWindowHours)

    $fresh = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($tenant in $tenants) {
        if ($tenant.LatestDate -ge $cutoff) {
            $fresh.Add($tenant)
        }
        else {
            Write-Warning ("Skipping stale tenant {0} (latest result {1:yyyy-MM-dd HH:mm}, more than {2}h before last audit {3:yyyy-MM-dd HH:mm})." -f `
                $tenant.TenantId, $tenant.LatestDate, $FreshnessWindowHours, $anchor)
        }
    }
    return $fresh
}

function Get-TestsResultsFailed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsDirectory,
        [double]$FreshnessWindowHours = 24
    )
    $failedTests = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($tenant in (Get-FreshTenantResults -ResultsDirectory $ResultsDirectory -FreshnessWindowHours $FreshnessWindowHours)) {
        $result = Get-Content $tenant.LatestFile.FullName -Raw | ConvertFrom-Json
        $tenantName = $result.TenantName
        foreach ($failedTest in ($result.Tests | Where-Object { $_.Result -eq 'Failed' })) {
            $failedTests.Add([PSCustomObject]@{
                'Tenant'   = $tenantName
                'Team'     = $result.Team
                'Severity' = $failedTest.Severity
                'Test'     = $failedTest.Name
                'Result'   = $failedTest.Result
            })
        }
    }
    return $failedTests
}

function Get-TestsResultsChanged {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsDirectory,
        [double]$FreshnessWindowHours = 24
    )
    $changedTests = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($tenant in (Get-FreshTenantResults -ResultsDirectory $ResultsDirectory -FreshnessWindowHours $FreshnessWindowHours)) {
        if ($tenant.Files.Count -lt 2) {
            Write-Warning "Directory $($tenant.TenantId) doesn't contain two test results."
            continue
        }
        $priorTest = Get-Content $tenant.Files[-2].FullName -Raw | ConvertFrom-Json
        $newTest   = Get-Content $tenant.Files[-1].FullName -Raw | ConvertFrom-Json
        $tenantName = $priorTest.TenantName
        $changes = Compare-MtTestResult -PriorTest $priorTest -NewTest $newTest
        foreach ($change in $changes) {
            $changedTests.Add([PSCustomObject]@{
                'Tenant'      = $tenantName
                'Team'        = $newTest.Team
                'Severity'    = $change.Severity
                'Test'        = $change.Name
                'PriorResult' = $change.PriorState
                'NewResult'   = $change.NewState
            })
        }
    }
    return $changedTests
}

function Export-FailureReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsDirectory,
        [string]$OutputPath = ".\failures-$((Get-Date).ToString('yyyy-MM-dd')).xlsx",
        [double]$FreshnessWindowHours = 24
    )
    $failed = Get-TestsResultsFailed -ResultsDirectory $ResultsDirectory -FreshnessWindowHours $FreshnessWindowHours
    $failed | Export-Excel -Path $OutputPath -AutoSize -FreezeTopRow -BoldTopRow `
        -TableName 'FailedTests' -TableStyle Medium9 -WorksheetName 'Failures'
    Write-Host "Report exported to: $OutputPath ($($failed.Count) failures)"
    return $OutputPath
}
