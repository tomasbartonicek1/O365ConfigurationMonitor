function Send-DailySummaryEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Config,
        [Parameter(Mandatory)]
        [PSCustomObject[]]$FailedTests,
        [Parameter(Mandatory)]
        [PSCustomObject[]]$ChangedTests
    )

    # TODO: Connect to MS Graph home tenant and send via POST /users/{sender}/sendMail
    # Example call:
    #   Connect-MgGraph -ClientId $Config.AppId -TenantId $Config.HomeTenantId -CertificateThumbprint $Config.CertificateThumbprint -NoWelcome
    #   Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($Config.EmailSender)/sendMail" -Body $mailBody

    throw 'Send-DailySummaryEmail is not yet implemented.'
}
