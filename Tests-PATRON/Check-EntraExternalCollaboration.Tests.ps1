BeforeAll{
    $authorizationPolicy = Get-MgPolicyAuthorizationPolicy
}

Describe "Checks guest invitation permissions" -Tag "PATRON.Entra.Check-GuestInvitationPermission", "PATRON", "Security", "User", "EntraID", "All" {
    It "Baseline: Checks if only admins and guest inviters are allowed to invite guests to M365 tenant."{
        $authorizationPolicy.AllowInvitesFrom -in @('none', 'AdminsAndGuestInviters') | Should -BeTrue -Because "only admins and guest inviters are allowed to invite guests to M365 tenant"
    }
}