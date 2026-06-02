$connectionConfig = [ConnectionConfig]@{
    AppId                 = 'xxx'
    CertificateThumbprint = 'xxx'
    HomeTenantId          = 'xxx'
}

$appConfig = [PSCustomObject]@{
    ResultsDirectory       = "$PSScriptRoot\results"
    ResultsDirectoryAudit  = "$PSScriptRoot\results-audit"
    ResultsDirectoryReport = "$PSScriptRoot\results-report"
    SharePointSiteUrl      = 'https://patronit.sharepoint.com/sites/IT'
    SharePointFolderPath   = 'Shared Documents/M365AuditReports'
    EmailSender            = 'notifications@yourdomain.cz'
    EmailRecipients        = @('admin@yourdomain.cz')

    # Customers detected by GDAP to exclude from audit
    ExcludedCustomers     = @(
        '1d6fc963-ce75-49a6-b983-b872eec7325b' #Customer ABC
    )

    # Extra customers to include that are not detected by GDAP
    AdditionalCustomers   = @(
        [PSCustomObject]@{
            DisplayName = 'ACME Corp'
            TenantId    = '0b65dafb-3999-41af-a347-16cb9e3c8b2d'
        }
    )

    # URL of CSV file with TenantId→Team mapping (columns: TenantId,Team)
    # Run Invoke-UpdateTeamMapping.ps1 to refresh the local cache from this URL
    TeamMappingUrl        = 'https://...'
    TeamMappingFile       = "$ScriptRoot\team-mapping.json"

    ResultsRetentionDays  = 90   # JSON result files older than this will be deleted by Invoke-CleanupOldReports.ps1
}
