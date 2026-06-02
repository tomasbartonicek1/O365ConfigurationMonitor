
BeforeAll{
    #Test if security defaults feature is enabled
    $securityDefaultEnabled = (Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy).IsEnabled
    $conditionalAccessPolicyFound = (Get-MgIdentityConditionalAccessPolicy -Property * -ExpandProperty * -Filter "State eq 'enabled'").count -gt 0
}

Describe "Checks security defaults or conditional access features configuration" -Tag "PATRON.Entra.Check-SecDefaultOrConditionalAccess", "PATRON", "Security", "Authentication", "EntraID", "All" {
    It "Baseline: Check active state of Security defaults or Conditional access feature."{
        Add-MtTestResultDetail -Severity 'Critical'
        ($securityDefaultEnabled -xor $conditionalAccessPolicyFound) | Should -BeTrue -Because "either security defaults or conditional access feature should be active"
    }
}
