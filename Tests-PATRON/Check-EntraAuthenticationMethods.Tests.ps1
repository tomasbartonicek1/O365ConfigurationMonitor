Describe "Checks enabled Entra ID user authentication methods" -Tag "PATRON.Entra.Check-AuthMethods","PATRON", "Security", "EntraID", "Authentication", "All" -Skip {
    It "Baseline: Checks secured Entra ID authentication methods (Fido2, Authenticator, TAP, Software OAUTH)." {
        Add-MtTestResultDetail -Severity 'Medium'
        $approvedAuthMethods = @('Fido2', 'MicrosoftAuthenticator', 'TemporaryAccessPass', 'SoftwareOath')
        $unapprovedAuthMethodFound = $false

        foreach ($method in $enabledAuthMethods) {
            if ($method.Id -notin $approvedAuthMethods) {
                $unapprovedAuthMethodFound = $true
            }
        }

        $unapprovedAuthMethodFound | Should -BeFalse -Because "only secured authentication methods (Fido2, Authenticator, TAP, Software OAUTH) should be enabled."
    }
}