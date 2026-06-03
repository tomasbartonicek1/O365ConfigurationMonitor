$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

if (-not $appConfig.ResultsRetentionDays -or $appConfig.ResultsRetentionDays -le 0) {
    Write-Error "ResultsRetentionDays is not configured or is invalid. Aborting cleanup to prevent accidental deletion."
    exit 1
}

$cutoff = (Get-Date).AddDays(-$appConfig.ResultsRetentionDays)
$deleted = 0

foreach ($tenantDir in (Get-ChildItem $appConfig.ResultsDirectory -Directory)) {
    foreach ($file in (Get-ChildItem $tenantDir.FullName -Filter 'Test-Results-*.json')) {
        $dateStr = $file.BaseName -replace '^Test-Results-', ''
        try {
            $fileDate = [datetime]::ParseExact($dateStr, 'yyyy-MM-dd-HHmmss',
                [System.Globalization.CultureInfo]::InvariantCulture)
        } catch {
            Write-Warning "Cannot parse date from filename: $($file.Name), skipping."
            continue
        }
        if ($fileDate -lt $cutoff) {
            Remove-Item $file.FullName
            $deleted++
        }
    }
}

Write-Host "Cleanup done: $deleted file(s) older than $($appConfig.ResultsRetentionDays) days deleted."
