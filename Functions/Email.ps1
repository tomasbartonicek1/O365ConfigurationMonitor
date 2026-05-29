function Send-DailySummaryEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig,
        [Parameter(Mandatory)]
        $AppConfig,
        [Parameter(Mandatory)]
        [PSCustomObject[]]$FailedTests,
        [Parameter(Mandatory)]
        [PSCustomObject[]]$ChangedTests
    )

    # TODO: Connect to MS Graph home tenant and send via POST /users/{sender}/sendMail
    # Example call:
    #   Connect-MgGraph -ClientId $ConnectionConfig.AppId -TenantId $ConnectionConfig.HomeTenantId -CertificateThumbprint $ConnectionConfig.CertificateThumbprint -NoWelcome
    #   Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($AppConfig.EmailSender)/sendMail" -Body $mailBody

    throw 'Send-DailySummaryEmail is not yet implemented.'
}
