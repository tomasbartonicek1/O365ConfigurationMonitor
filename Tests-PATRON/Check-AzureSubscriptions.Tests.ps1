Describe "Checks Azure subscriptions migration policy" -Tag "PATRON.Azure.Check-SubscriptionPolicy", "PATRON", "Azure", "Subscription", "All"{
    BeforeAll{
        try{
            $subscriptionPolicy = Get-AzSubscriptionPolicy -ErrorAction SilentlyContinue
        }catch{
            $subscriptionPolicy = $null
        }
    }

    It "Baseline: Migration of subscription from and to Azure tenant should be blocked" {
        Add-MtTestResultDetail -Severity 'Medium'
        if($subscriptionPolicy){
            ($subscriptionPolicy.BlockSubscriptionsIntoTenant -and $subscriptionPolicy.BlockSubscriptionsLeavingTenant) | Should -BeTrue -Because "migration of subscriptions from and to Azure tenant should be blocked."
        }elseif (-not $subscriptionPolicy) {
            $subscriptionPolicy | Should -Not -BeNullOrEmpty -Because "subscription policy should exists and be set to block migration subscription from and to Azure tenant"
        }
    }
}