BeforeAll {
    $approvedAuthMethods = @('#microsoft.graph.microsoftAuthenticatorAuthenticationMethod', '#microsoft.graph.softwareOathAuthenticationMethod')
    $entraLicensedUsers = Get-MgUser -Filter ("accountEnabled eq true and assignedLicenses/`$count ne 0 and " + "userType eq 'Member'") -All -Property Id, accountEnabled, Mail, UserPrincipalName, DisplayName, AssignedLicenses -ConsistencyLevel eventual -CountVariable $licencedUserCount
}


Describe "Checks MFA setup status for all licensed and active user accounts" -Tag "PATRON.Entra.Check-MFARegistrationStatus", "PATRON", "Security", "User", "Authentication", "EntraID", "All"{
    It "Baseline: Check MFA registration for all licenced and active user accounts."{
        Add-MtTestResultDetail -Severity 'Medium'
        $unsecuredUsers = @()
    
        foreach ($user in $unsecuredUsers) {
            $userAuthMethods = (Get-MgUserAuthenticationMethod -UserId $user.Id -All -Filter "Id ne '28c10230-6103-485e-b985-444c60001490'").AdditionalProperties.'@odata.type'

            if ((Compare-Object -ReferenceObject $userAuthMethods -DifferenceObject $approvedAuthMethods -IncludeEqual -ExcludeDifferent).Count -eq 0)
            {
                $unsecuredMethods = $userAuthMethods.replace('#microsoft.graph.','').replace('AuthenticationMethod','') -join ', '

                $unsecuredUsers += $user
                Write-Host '[DEBUG] User $($user.UserPrincipalName) has not MFA registered'
            }
        }

        $unsecuredUsers.Count | Should -Be 0 -Because "all licensed and active users should have registered at least one MFA method" 
    }
}