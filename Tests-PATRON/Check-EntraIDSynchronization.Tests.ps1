BeforeAll{
    $pendingRegDevices = Get-MgDevice -All -Filter "TrustType eq 'ServerAd'" | Where-Object { ($_.ProfileType -ne "RegisteredDevice") -and (-not $_.AlternativeSecurityIds) } 
}

Describe "Checks Entra ID synchronized devices are not in pending registration state" -Tag "PATRON.Entra.Check-PendingRegistrationDevices","PATRON", "Device", "EntraID", "All" {
    It "Baseline: Checks whether Entra ID synchronized devices are not in pending registration state."{
        $pendingRegDevices.Count | Should -Be 0 -Because "no Entra ID synchronized devices should not be in pending registration state"
    }
}