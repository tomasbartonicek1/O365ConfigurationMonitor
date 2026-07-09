$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

$logDir = "$ScriptRoot\logs"
if (!(Test-Path $logDir)) { New-Item $logDir -ItemType Directory | Out-Null }
$logFile = "$logDir\run-$((Get-Date).ToString('yyyy-MM-dd')).log"
Start-Transcript -Path $logFile -Append

$startTime = Get-Date
Write-Host "=== Invoke-All started at $startTime ==="

try {
    Write-Host "--- UpdateTeamMapping: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-UpdateTeamMapping.ps1"

    Write-Host "--- Audit: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-Audit.ps1"

    Write-Host "--- ReportExcel: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-ReportExcel.ps1"

    Write-Host "--- ReportHtml: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-ReportHtml.ps1"

    Write-Host "--- SharePointUpload: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-SharePointUpload.ps1"

    Write-Host "--- DailySummary: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-DailySummary.ps1"

    Write-Host "--- CleanupOldReports: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-CleanupOldReports.ps1"
}
catch {
    Write-Host "=== FATAL ERROR: $_ ===" -ForegroundColor Red
}
finally {
    $duration = (Get-Date) - $startTime
    Write-Host "=== Invoke-All finished at $(Get-Date) (duration: $($duration.ToString('hh\:mm\:ss'))) ==="
    Stop-Transcript
}
