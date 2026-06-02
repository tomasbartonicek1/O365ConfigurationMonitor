BeforeAll {
    $aadDomains = Get-MgDomain -All
}

Describe "Checks verified state of all Entra ID domains" -Tag "PATRON.Entra.Check-DomainVerification", "PATRON", "Security", "Domains", "EntraID", "All" {
    It "Baseline: Check verification status of Entra ID domains." {
        Add-MtTestResultDetail -Severity 'Medium'
        $unverifiedDomains = $aadDomains | Where-Object { $_.isVerified -ne $true}
        $unverifiedDomains | Should -HaveCount 0 -Because ('All Entra ID domain should be verified.')
    }
}

Describe "Check no Entra ID domains are in federated mode" -Tag "PATRON.Entra.Check-NoFederatedDomains", "PATRON", "Security", "Domains", "EntraID", "All" {
    It "Baseline: All Entra ID domains should be in 'Managed' mode." {
        Add-MtTestResultDetail -Severity 'High'
        $federatedDomains = $aadDomains | Where-Object { $_.AuthenticationType -ne 'Managed' }
        $federatedDomains | should -HaveCount 0 -Because "All Entra ID domains should be in 'Managed' mode"
    }
}