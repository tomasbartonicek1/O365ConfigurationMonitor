BeforeDiscovery{
    $entraLicense = Get-MtLicenseInformation -Product EntraID
}

Describe "Checks if unified audit logging (MS Purview Standard) is enabled" -Skip:($entraLicense -eq "Free") -Tag "PATRON.Purview.Check-UnifiedAuditLogEnabled","Patron","Security","Purview","Logging","All"{
    It "Baseline: Check unified audit logging enabled status." {
        #Use the ExchangeOnlineManagement PS module strictly because of duplicate PS cmdlet name with Security & Compliance module
         #Requires -Modules ExchangeOnlineManagement
         (Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled | Should -BeTrue -Because "unified audit logging should be enabled."
    }
}