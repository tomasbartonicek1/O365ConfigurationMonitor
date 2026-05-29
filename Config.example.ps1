$config = [PSCustomObject]@{
    'CertificateThumbprint' = 'xxx'
    'HomeTenantId' = 'xxx'
    'AppId' = 'xxx'
    'ResultsDirectory' = 'C:\O365Baseline\test-results'
    'ResultsDirectoryAudit' = 'C:\O365Baseline\test-results-audit'
}

# Which customers to exclude even if they were detected by GDAP
$excludedCustomers = @(
    '1d6fc963-ce75-49a6-b983-b872eec7325b' #Customer ABC
)

# Which extra customers to include in test - in case they are not detected by GDAP
$includedCustomers = @(
    [PSCustomObject]@{
        DisplayName = 'ACME Corp'
        TenantId = '0b65dafb-3999-41af-a347-16cb9e3c8b2d'
    }
)

$pesterConfig = [PesterConfiguration]@{
    Should = @{
        Show = 'Default'
    }
}
