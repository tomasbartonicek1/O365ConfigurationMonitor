$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

$logDir = "$ScriptRoot\logs"
if (!(Test-Path $logDir)) { New-Item $logDir -ItemType Directory | Out-Null }
$logFile = "$logDir\run-$((Get-Date).ToString('yyyy-MM-dd')).log"
Start-Transcript -Path $logFile -Append

$startTime = Get-Date
Write-Host "=== Invoke-All started at $startTime ==="

$currentStep = $null
try {
    $currentStep = 'UpdateTeamMapping'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-UpdateTeamMapping.ps1"

    $currentStep = 'Audit'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-Audit.ps1"

    $currentStep = 'ReportExcel'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-ReportExcel.ps1"

    $currentStep = 'ReportHtml'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-ReportHtml.ps1"

    $currentStep = 'SharePointUpload'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-SharePointUpload.ps1"

    $currentStep = 'DailySummary'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-DailySummary.ps1"

    $currentStep = 'CleanupOldReports'
    Write-Host "--- $currentStep: $(Get-Date -Format 'HH:mm:ss') ---"
    & "$ScriptRoot\Invoke-CleanupOldReports.ps1"
}
catch {
    Write-Host "=== FATAL ERROR in step '$currentStep': $_ ===" -ForegroundColor Red
}
finally {
    $duration = (Get-Date) - $startTime
    Write-Host "=== Invoke-All finished at $(Get-Date) (duration: $($duration.ToString('hh\:mm\:ss'))) ==="
    Stop-Transcript
}
