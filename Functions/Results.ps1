function Get-TestsResultsFailed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsDirectory
    )
    $failedTests = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($directory in (Get-ChildItem $ResultsDirectory -Directory)) {
        $latestJsonFile = Get-ChildItem $directory.FullName -Filter *.json | Sort-Object CreationTimeUtc | Select-Object -Last 1
        if (-not $latestJsonFile) {
            Write-Warning "No result files in $($directory.Name), skipping."
            continue
        }
        $result = Get-Content ($directory.FullName + '\' + $latestJsonFile.Name) -Raw | ConvertFrom-Json
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
        [string]$ResultsDirectory
    )
    $changedTests = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($directory in (Get-ChildItem $ResultsDirectory -Directory)) {
        $latestJsonFiles = Get-ChildItem $directory.FullName -Filter *.json | Sort-Object CreationTimeUtc | Select-Object -Last 2
        if ($latestJsonFiles.Count -ne 2) {
            Write-Warning "Directory $($directory.Name) doesn't contain two test results."
        }
        else {
            $priorTest = Get-Content ($directory.FullName + '\' + $latestJsonFiles[0].Name) -Raw | ConvertFrom-Json
            $newTest   = Get-Content ($directory.FullName + '\' + $latestJsonFiles[1].Name) -Raw | ConvertFrom-Json
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
    }
    return $changedTests
}

function Export-FailureReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResultsDirectory,
        [string]$OutputPath = ".\failures-$((Get-Date).ToString('yyyy-MM-dd')).xlsx"
    )
    $failed = Get-TestsResultsFailed -ResultsDirectory $ResultsDirectory
    $failed | Export-Excel -Path $OutputPath -AutoSize -FreezeTopRow -BoldTopRow `
        -TableName 'FailedTests' -TableStyle Medium9 -WorksheetName 'Failures'
    Write-Host "Report exported to: $OutputPath ($($failed.Count) failures)"
    return $OutputPath
}
