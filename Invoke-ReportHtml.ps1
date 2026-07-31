$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

Import-Module Maester

$htmlDir = $appConfig.ResultsDirectoryReport

if (-not (Test-Path $htmlDir)) {
    New-Item -ItemType Directory -Path $htmlDir | Out-Null
}

$freshnessWindow = if ($appConfig.ResultFreshnessWindowHours) { $appConfig.ResultFreshnessWindowHours } else { 24 }
$freshTenants = Get-FreshTenantResults -ResultsDirectory $appConfig.ResultsDirectory -FreshnessWindowHours $freshnessWindow
$allResults = [System.Collections.Generic.List[psobject]]::new()

foreach ($tenant in $freshTenants) {
    $latestFile = $tenant.LatestFile

    $result = (Import-MtMaesterResult -Path $latestFile.FullName)[0]

    $notRunCount        = @($result.Tests | Where-Object { $_.Result -eq 'NotRun' }).Count
    $result.Tests       = @($result.Tests | Where-Object { $_.Result -ne 'NotRun' })
    $result.NotRunCount = 0
    $result.TotalCount  = $result.Tests.Count

    $displayName = if ($result.TenantName) { $result.TenantName } else { $tenant.TenantId }
    $safeName    = $displayName -replace '[\\/:*?"<>|]', '_'
    $outputFile  = Join-Path $htmlDir "$safeName.html"

    Write-Host "[$displayName] $($latestFile.Name) -> $outputFile (excluded $notRunCount not-run tests)"

    $result | Get-MtHtmlReport | Out-File -FilePath $outputFile -Encoding UTF8
    $allResults.Add($result)
}

if ($allResults.Count -gt 0) {
    $mergedFile = Join-Path $htmlDir '_summary.html'
    Write-Host "Generating merged report ($($allResults.Count) tenants) -> $mergedFile"
    $allResults | Sort-Object TenantName | Merge-MtMaesterResult | Get-MtHtmlReport | Out-File -FilePath $mergedFile -Encoding UTF8
}

Write-Host "Done. HTML reports saved to: $htmlDir"
