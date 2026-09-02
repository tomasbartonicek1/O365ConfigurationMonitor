    BeforeDiscovery{
        $entraLicense = Get-MtLicenseInformation -Product EntraID
    }

    BeforeAll {
        #TEMP until Maester release prod version which this test included
        . .\Tests-PATRON\Test-MtDeviceRegistrationMfaConflict.ps1

        function Compare-CapWithBaseline {
            param (
                [Parameter(Mandatory)]
                [pscustomobject]$ActualCap,
                [Parameter(Mandatory)]
                [pscustomobject]$BaselineCap,
                [string]$Path = "",
                [hashtable]$CustomComparers = @{}
            )

            $differences = @()

            foreach ($property in $BaselineCap.PSObject.Properties) {
                $propName = $property.Name
                $currentPath = if ($Path) { "$Path.$propName" } else { $propName }

                $actualValue = $ActualCap.PSObject.Properties[$propName]?.Value
                $baselineValue = $property.Value

                if ($baselineValue -is [PSCustomObject]) {
                    # Recursive compare for objects
                    if ($null -eq $actualValue) {
                        $differences += "Difference at $($currentPath): property missing in actual CAP"
                    }
                    else {
                        $diff = Compare-CapWithBaseline -ActualCap $actualValue -BaselineCap $baselineValue -Path $currentPath -CustomComparers $CustomComparers
                        if ($diff) { $differences += $diff }
                    }
                }
                elseif ($baselineValue -is [System.Collections.IEnumerable] -and -not ($baselineValue -is [string])) {
                    # Custom comparer?
                    if ($CustomComparers.ContainsKey($currentPath)) {
                        $diff = & $CustomComparers[$currentPath] $actualValue $baselineValue $currentPath
                        if ($diff) { $differences += $diff }
                    }
                    else {
                        # Default array comparison
                        if ($null -eq $actualValue -or $actualValue.Count -ne $baselineValue.Count) {
                            $differences += "Difference at $($currentPath): Array length differs (actual=$($actualValue.Count), baseline=$($baselineValue.Count))"
                        }
                        else {
                            for ($i = 0; $i -lt $baselineValue.Count; $i++) {
                                $itemPath = "$currentPath[$i]"
                                $diff = Compare-CapWithBaseline -ActualCap $actualValue[$i] -BaselineCap $baselineValue[$i] -Path $itemPath -CustomComparers $CustomComparers
                                if ($diff) { $differences += $diff }
                            }
                        }
                    }
                }
                else {
                    # Compare scalar values
                    if ($actualValue -ne $baselineValue) {
                        $differences += "Difference at $($currentPath): actual='$actualValue', baseline='$baselineValue'"
                    }
                }
            }

            return $differences
        }

        function Test-PtCaForBaseline {
            [CmdletBinding()]
            [OutputType([bool])]
            param (
                [Parameter(Mandatory)]
                [pscustomobject]$baseline,
                [hashtable]$CustomComparers = @{}        
            )
            $policies = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }
            $policiesResult = New-Object System.Collections.ArrayList
            $result = $false

            if ($baseline.templateId) {
                $baseline.PSObject.Properties.Remove('templateId')
                $baseline.PSObject.Properties.Remove('displayName')
                $baseline.conditions.users.PSObject.Properties.Remove('excludeUsers')
                $baseline.conditions.users.PSObject.Properties.Remove('excludeGroups')
            }

            write-host $baseline.DisplayName
            # Just to be sure add attribute to check if CAP is enabled
            if (!$baseline.state) {
                $baseline | Add-Member -MemberType NoteProperty -Name "state" -Value "enabled"
            }
        

            foreach ($policy in $policies) {
                $differences = Compare-CapWithBaseline -ActualCap $policy -BaselineCap $baseline -CustomComparers $CustomComparers

                if ($differences.Count -eq 0) {
                    $result = $true
                    $currentresult = $true
                    $policiesResult.Add($policy) | Out-Null
                }
                else {
                    $currentresult = $false 
                }
                Write-Verbose "$($policy.displayName) - $currentresult"
            }

            return $result
        }
    }

    Context "CA policies check" -Skip:($entraLicense -eq "Free"){
        Describe "Checks CA policy 'BASE: Block legacy auth'" -Tag "PATRON.Entra.Test-PtCaBaseBlockLegacyAuthentication", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: Block legacy auth' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-Block legacy auth.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'BASE: Block legacy auth' should be present and active"
            }
        }

        Describe "Checks CA policy 'BASE: Securing security info registration'" -Tag "PATRON.Entra.Test-PtCaBaseSecureInfoRegistration", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: Securing security info registration' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-Secure security info registration.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'BASE: Securing security info registration' should be present and active"
            }
        }

        Describe "Checks CA policy 'BASE: Block device code flow authentication'" -Tag "PATRON.Entra.Test-PtCaBaseBlockDeviceCodeFlow", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: Block device code flow authentication' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-Block Device Code Flow Authentication.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'BASE: Block device code flow authentication' should be present and active"
            }
        }

        Describe "Checks CA policy 'USERS: Block guests with high sign-in risk'" -Tag "PATRON.Entra.Test-PtCaUsersBlockGuestsHighSignInRisk", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" -Skip:($entraLicense -ne "P2") {
            It "Baseline: CA policy 'USERS: Block guests with high sign-in risk' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\USERS-Block guests with high sign-in risk.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'USERS: Block guests with high sign-in risk' should be present and active"
            }
        }

        Describe "Checks CA policy 'USERS: Block guests with high user risk'" -Tag "PATRON.Entra.Test-PtCaUsersBlockGuestsHighUserRisk", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" -Skip:($entraLicense -ne "P2") {
            It "Baseline: CA policy 'USERS: Block guests with high user risk' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\USERS-Block guests with high user risk.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'USERS: Block guests with high user risk' should be present and active"
            }
        }

        Describe "Checks CA policy 'BASE: Require MFA'" -Tag "PATRON.Entra.Test-PtCaBaseRequireMFA", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: Require MFA' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-MFA require.json" | ConvertFrom-Json
                $result = $false
                $possibleControls = @(
                    @("mfa", "compliantDevice", "domainJoinedDevice"),
                    @("mfa", "compliantDevice"),        
                    @("mfa", "domainJoinedDevice"),        
                    @("mfa")
                )
                foreach ($control in $possibleControls) {
                    $baseline.grantControls.builtInControls = $control
                    if (Test-PtCaForBaseline $baseline) {
                        $result = $true
                    }
                }
                $result | Should -BeTrue -Because "CA policy 'BASE: Require MFA' should be present and active"
            }
        }

        Describe "Checks CA policy 'BASE: No persistent session'" -Tag "PATRON.Entra.Test-PtCaBaseNoPersistentSession", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: No persistent session' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-No persistent session.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'BASE: No persistent session' should be present and active"
            }
        }

        Describe "Checks CA policy 'BASE: Require MFA and sign-in frequency for admins'" -Tag "PATRON.Entra.Test-PtCaBaseMFAForAdmins", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: Require MFA and sign-in frequency for admins' is present and active" {
                Add-MtTestResultDetail -Severity 'Critical'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-Require MFA and sign in frequency for admins.json" | ConvertFrom-Json
                $CustomComparers = @{
                    'conditions.users.includeRoles' = {
                        param($actual, $baseline, $path)
                        $missing = @()
                        foreach ($role in $baseline) {
                            if (-not ($actual -contains $role)) {
                                $missing += $role
                            }
                        }
                        if ($missing.Count -gt 0) {
                            return "Difference at $($path): roles missing in actual CAP: $($missing -join ', ')"
                        }
                        return $null
                    }
                }
                Test-PtCaForBaseline $baseline -CustomComparers $CustomComparers | Should -BeTrue -Because "CA policy 'BASE: Require MFA and sign-in frequency for admins' should be present and active"
            }
        }

        Describe "Checks CA policy 'BASE: Secure device registration or join'" -Tag "PATRON.Entra.Test-PtCaBaseSecureDeviceRegistration", "PATRON.Entra-TestPtCaPolicies", "PATRON", "Security", "CA", "EntraID", "All" {
            It "Baseline: CA policy 'BASE: Secure device registration or join' is present and active" {
                Add-MtTestResultDetail -Severity 'High'
                $baseline = Get-Content ".\Tests-PATRON\CAPTemplates\BASE-Secure device registration or join.json" | ConvertFrom-Json
                Test-PtCaForBaseline $baseline | Should -BeTrue -Because "CA policy 'BASE: Secure device registration or join' should be present and active"
            }
        }

        Describe "Checks device registration MFA control conflicts with Conditional Access policies" -Tag "MT.1061", "Maester", "Security", "CA", "EntraID", "All" {
            It "MT.1061: Device registration MFA control conflicts with Conditional Access policies. See https://maester.dev/docs/tests/MT.1061" -Tag "MT.1061" {
                Add-MtTestResultDetail -Severity 'Medium'
                Test-MtDeviceRegistrationMfaConflict | Should -Be $true -Because "there is a conflict between Entra ID settings and Conditional Access policies regarding MFA during device registration."
            }
        }

    }