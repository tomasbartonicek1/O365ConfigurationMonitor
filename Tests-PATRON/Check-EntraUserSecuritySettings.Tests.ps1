BeforeAll {
    $authorizationPolicy = Get-MgPolicyAuthorizationPolicy
    $deviceRegistrationPolicy = Get-MgBetaPolicyDeviceRegistrationPolicy
    $deviceJoinPolicy = $deviceRegistrationPolicy.AzureAdJoin.AllowedToJoin.AdditionalProperties
    $deviceJoinPermission = $deviceJoinPolicy.'@odata.type'

    $appConsentPolicy = $authorizationPolicy.DefaultUserRolePermissions.PermissionGrantPoliciesAssigned

    $unifiedGroupSettings = (Get-MgGroupSetting | Where-Object { $_.TemplateId -eq '62375ab9-6b52-47ed-826b-58e47e0e304b' }).Values
    $groupConsentSetting = (Get-MgGroupSetting | Where-Object { $_.TemplateId -eq 'dffd5d46-495d-40a9-8e21-954ff55e198a' }).Values
}

Describe "Checks Entra ID device join permissions" -Tag "PATRON.Entra.Check-DeviceJoinPermission", "PATRON", "Security", "Device", "EntraID", "All" {
    It "Baseline: Users can not join devices to Entra ID" {
        $deviceJoinPermission | Should -BeIn @('#microsoft.graph.enumeratedDeviceRegistrationMembership', '#microsoft.graph.noDeviceRegistrationMembership') -Because 'users should not join devices to Entra ID.'
    }

    It "Baseline: MFA should not be required to device join via deviceJoin settings" {
        $deviceRegistrationPolicy.MultiFactorAuthConfiguration | Should -Be 'notRequired' -Because 'MFA should not be required to devices join via deviceJoin settings.'
    }

    It "Baseline: Only specific group members (PRIV-Device-Join) can join devices to Entra ID." -Skip:($deviceJoinPermission -ne '#microsoft.graph.enumeratedDeviceRegistrationMembership') {
        $deviceJoinGroupId = $deviceJoinPolicy.groups | Select-Object -First 1

        $groupObject = Get-MgGroup -GroupId $deviceJoinGroupId

        $groupObject.DisplayName.ToLower() | Should -Be 'priv-device-join' -Because 'only "PRIV-Device-Join" group should join devices to Entra ID'
    }
}

Describe "Checks Entra ID device registration permissions" -Tag "PATRON.Entra.Check-DeviceRegistrationPermission", "PATRON", "Security", "Device", "EntraID", "All" {
    It "Baseline: Users can register devices to Entra ID" {
        $deviceRegistrationPolicy.AzureAdRegistration.AllowedToRegister.AdditionalProperties.'@odata.type' | Should -Be '#microsoft.graph.allDeviceRegistrationMembership' -Because 'users should be able to register devices to Entra ID.'
    }
}

Describe "Checks Entra ID BitLocker keys read restriction for users" -Tag "PATRON.Entra.Check-BitLockerKeysReadRestriction", "PATRON", "Security", "Device", "EntraID", "All" {
    It "Baseline: Users can not read BitLocker keys for their owned devices" {
        $authorizationPolicy.DefaultUserRolePermissions.AllowedToReadBitlockerKeysForOwnedDevice | Should -BeFalse -Because 'users should not read BitLocker keys for their owned devices.'
    }
}

Describe "Checks Entra ID application registration policy" -Tag "PATRON.Entra.Check-AppRegistrationPolicy", "PATRON", "Security", "User", "Application", "EntraID", "All" {
    It "Baseline: Users can not register Entra ID applications" {
        $authorizationPolicy.DefaultUserRolePermissions.AllowedToCreateApps | Should -BeFalse -Because "users should not register Entra ID applications"
    }
}

Describe "Checks Entra ID applications consent policy for users" -Tag "PATRON.Entra.Check-AppConsentPolicy", "PATRON", "Security", "User", "Application", "EntraID", "All" {
    It "Baseline: Users can not consent any Entra ID applications" {
        $consentPoliciesFiltered = $appConsentPolicy | Where-Object { $_ -notin @('ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-team', 'ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-chat') }

        $consentPoliciesFiltered | Should -BeNullOrEmpty -Because "users should not consent Entra ID applications"
    }
}

Describe "Checks admin consent requests status" -Tag "PATRON.Entra.Check-AdminConsentRequestSettings", "PATRON", "Security", "User", "Application", "EntraID", "All" {
    It "Baseline: Users can create admin consent requests" {
        (Get-MgPolicyAdminConsentRequestPolicy).IsEnabled | Should -BeTrue -Because "users should be able to create admin consent requests"
    }
}

Describe "Checks groups creation permission" -Tag "PATRON.Entra.Check-GroupCreatePermission", "PATRON", "Security", "User", "Groups", "EntraID", "All" {
    It "Baseline: Users can not create Entra ID groups" {
        $authorizationPolicy.DefaultUserRolePermissions.AllowedToCreateSecurityGroups | Should -BeFalse -Because "users should not create Entra ID security groups."
    }
    It "Baseline: Users can not create M365 groups" {
        ($unifiedGroupSettings | Where-Object { $_.Name -eq "EnableGroupCreation" }).Value | Should -Be "false" -Because "users should not create M365 groups."
    }
}

Describe "Checks create new M365 tenants permission" -Tag "PATRON.Entra.Check-TenantCreatePermission", "PATRON", "Security", "User", "EntraID", "All" {
    It "Baseline: Users can not create M365 tenants" {
        $authorizationPolicy.DefaultUserRolePermissions.AllowedToCreateTenants | Should -BeFalse -Because "users should not create new M365 tenants."
    }
}

Describe "Checks restrict non-admin access to Microsoft Entra admin center" -Tag "PATRON.Entra.Check-RestrictEntraAdminCenterAccess", "PATRON", "Security", "User", "EntraID", "All" -Skip {
    It "Baseline: Users can not have access to Microsoft Entra admin center" {
        (Invoke-MtGraphRequest -RelativeUri "admin/entra/uxSetting" -ApiVersion beta).restrictNonAdminAccess | should -BeTrue -Because "users should not have access to Microsoft Entra admin center."
    }
}

Describe "Checks SSPR feature status for admins" -Tag "PATRON.Entra.Check-SSPRForAdminsDisabled", "PATRON", "Security", "User", "Authentication", "EntraID", "All" -Skip {
    It "Baseline: SSPR feature is disabled for admins" {
        $authorizationPolicy.AllowedToUseSspr | Should -BeFalse -Because "admins should not reset their passwords themselves by SSPR."
    }
}

Describe "Checks Reset user risk status after on-premises password change" -Tag "PATRON.Entra.Check-ResetUserRiskAfterOnPremPwdChange", "PATRON", "Security", "User", "Authentication", "EntraID", "All" {
    BeforeDiscovery {
        $onPremSyncEnabled = (Get-MgOrganization).OnPremisesSyncEnabled
    }

    It "Baseline: Reset user risk status after on-premises password change is enabled" -Skip:([String]::IsNullOrEmpty($onPremSyncEnabled) -or -not $onPremSyncEnabled) {
        (Invoke-MtGraphRequest -RelativeUri "identityProtection/policy" -ApiVersion beta).isUserRiskClearedOnPasswordReset | should -BeTrue -Because "user risk status should be reset after on-premises password change."
    }
}

Describe "Checks Breakglass emergency access account presence and role assignment" -Tag "PATRON.Entra.Check-BreakglassAccount", "PATRON", "Security", "User", "Authentication", "EntraID", "All" {
        BeforeAll {
            $breakGlassAccount = Get-MgUser -Filter "startsWith(userPrincipalName,'breakglass@')" -All
        }

        It "Baseline: Breakglass emergency access account is present" {
            $breakGlassAccount.Count | Should -BeGreaterThan 0 -Because "breakglass emergency access account should be present"
        }

        It "Baseline: Breakglass emergency access account has Global Administrator role assigned" {
            if($breakGlassAccount.Count -eq 0){
                Set-ItResult -Skipped -Because "breakglass emergency access account not found"
            }

            $breakglassUserId = (Get-MgUser -Filter "startsWith(userPrincipalName,'breakglass@')" -All).Id
            $globalAdminRoleId = (Get-MgDirectoryRole -Filter "DisplayName eq 'Global Administrator'").Id
    
            (Get-MgDirectoryRoleMember -DirectoryRoleId $globalAdminRoleId | Where-Object { $_.Id -eq $breakGlassUserId }).Count | Should -BeGreaterThan 0 -Because "breakglass emergency access account should have global administrator role assigned."
        }
}