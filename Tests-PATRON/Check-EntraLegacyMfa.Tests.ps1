BeforeAll{
    $mfaServicePolicy = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/policies/mfaServicePolicy"
}

Describe "Checks migration state of legacy user-based MFA authentication" -Tag "PATRON.Entra.Check-MFAMigrationState","PATRON", "Security", "EntraID", "Authentication", "All" -Skip {
    It "Baseline: Checks legacy user-based MFA is migrated completely to conditional access." {
        (Get-MgPolicyAuthenticationMethodPolicy).PolicyMigrationState | Should -BeIn @("migrationComplete", $null) -Because "legacy user-based MFA should be migrated completely to Entra ID authentication methods"
    }
}

Describe "Checks whether the 'Remember MFA on trusted devices' option is disabled" -Tag "PATRON.Entra.Check-RememberMFADisabled","PATRON", "Security", "EntraID", "Authentication", "All" {
    It "Baseline: Checks option for remember MFA on trusted devices is disabled."{
        $mfaServicePolicy.rememberMfaOnTrustedDevice.isEnabled | should -BeFalse -Because "users should not be able remember MFA on trusted devices."
    }
}

Describe "Checks whether users can not create application passwords for non-browser legacy apps" -Tag "PATRON.Entra.Check-AppPasswordsDisabled","PATRON", "Security", "EntraID", "Authentication", "All" {
    It "Baseline: Checks users can not create application passwords for non-browser legacy apps."{
        $mfaServicePolicy.allowAppPasswords | Should -BeFalse -Because "users should not be able to create application passwords."
    }
}

Describe "Checks whether no IP subnets are excluded for MFA requests in legacy per-user MFA config" -Tag "PATRON.Entra.Check-MFALegacyIPWhitelist","PATRON", "Security", "EntraID", "Authentication", "All" {
    It "Baseline: Checks no IP subnets are excluded for MFA requests in legacy per-user MFA config."{
        $mfaServicePolicy.trustedIps.ips | Should -BeNullOrEmpty -Because "no IP subnets should be excluded for MFA requests in legacy per-user MFA config."
    }
}

Describe "Checks whether no user have deprecated per-user MFA configured" -Tag "PATRON.Entra.Check-MFALegacyConfiguredUsers","PATRON", "Security", "EntraID", "Authentication", "All"{
    It "Baseline: Checks no users have deprecated per-user MFA configured"{
        $legacyMfaUserConfigured = 0

        $userIdArray = Get-MgUser -All | Select-Object -ExpandProperty Id 

        foreach($userId in $userIdArray){
            $perUserMfaState = (Invoke-MtGraphRequest -ApiVersion beta -RelativeUri "users/$($userId)/authentication/requirements" -OutputType PSObject).perUserMfaState

            if($perUserMfaState -in @('enabled','enforced')){
                $legacyMfaUserConfigured++
            }
        }

        $legacyMfaUserConfigured | Should -Be 0 -Because 'no users should be per-user MFA configured.'
    }
}