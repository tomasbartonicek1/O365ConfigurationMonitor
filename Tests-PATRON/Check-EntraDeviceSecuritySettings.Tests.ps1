BeforeAll {
    $deviceRegistrationPolicy = Get-MgBetaPolicyDeviceRegistrationPolicy
}

Describe "Checks Entra ID device join local admins settings" -Tag "PATRON.Entra.Check-DeviceLocalAdminsPolicy", "PATRON", "Security", "Device", "EntraID", "All" {
    It "Baseline: Global administrators should not became local admins on device after join" {
        Add-MtTestResultDetail -Severity 'Medium'
        $deviceRegistrationPolicy.AzureAdJoin.LocalAdmins.EnableGlobalAdmins | Should -BeFalse -Because "global administrators should not became local admins on joined device."
    }

    It "Baseline: Registering user should not became local administrator on registered device" {
        Add-MtTestResultDetail -Severity 'Medium'
        $deviceRegistrationPolicy.AzureAdJoin.LocalAdmins.RegisteringUsers.AdditionalProperties.'@odata.type' | Should -Be "#microsoft.graph.noDeviceRegistrationMembership" -Because "registering users should not became local administrator on registered device."
    }
}