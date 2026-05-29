Describe "Checks Entra ID application registration policy" -Tag "PATRON", "Security", "GDAP", "EntraID", "All" {
    It "Baseline: There are only approved GDAP relationships." {
        $partners = Get-MgBetaPolicyCrossTenantAccessPolicyPartner | Where-Object {$_.IsServiceProvider -eq $true}
        $partnersNames = @($partners | ForEach-Object {Get-TenantDisplayName -tenantId $_.TenantId})
        #$result = [bool]($partnersNames -eq @('PATRON-IT s.r.o.'))
        Add-MtTestResultDetail -Result 'Neco se pokazilo' -Description 'Tohle je description'
        $partnersNames | Should -Be @('PATRON-IT s.r.o.') -Because "Customer has GDAP only with PATRON-IT s.r.o."
    }
}

Describe "Parameter passing test" -Tag "Beta" {
    It "We cann see Env variable." {
        Write-Host "X: $($a.a)"
        $true | Should -BeTrue
    }
}