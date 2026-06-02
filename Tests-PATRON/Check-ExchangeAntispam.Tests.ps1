BeforeAll{
    $hostedConnectionFilterPolicies = Get-HostedConnectionFilterPolicy
    $hostedContentFilterPolicies = Get-HostedContentFilterPolicy
    $hostedOutboundSpamFilterPolicies = Get-HostedOutboundSpamFilterPolicy
    $antiphishPolicies = Get-AntiPhishPolicy

    $antispamPoliciesAllowedSenderDomains = $hostedContentFilterPolicies.AllowedSenders.Sender.Domain
    $companyMailDomains = (Get-MgDomain -all | Where-Object {$_.SupportedServices -contains 'Email'}).Id
}

Describe "Recommended spam filter actions are configured" -Tag "PATRON.Exchange.Antispam.Check-SpamFilterActions", "PATRON", "Security", "Exchange", "Antispam", "All"{
    It "Baseline: Spam filter actions are configured to MoveToJunk/Quarantine" {
        Add-MtTestResultDetail -Severity 'High'
        $hostedContentFilterPolicies.SpamAction | Should -BeIn @("MoveToJmf","Quarantine")
        $hostedContentFilterPolicies.HighConfidenceSpamAction | Should -BeIn @("MoveToJmf","Quarantine")
        $hostedContentFilterPolicies.HighConfidencePhishAction | Should -BeIn @("MoveToJmf","Quarantine")
    }
}

Describe "Checks no company-domain sender exceptions in spam filter policies" -Tag "PATRON.Exchange.Antispam.Check-CompanyDomainSenderException", "PATRON", "Security", "Exchange", "Antispam", "All" -Skip:(-not $antispamPoliciesAllowedSenderDomains) {
    It "Baseline: No company-domain sender exceptions in spam filter policies" {
        Add-MtTestResultDetail -Severity 'Medium'
        (Compare-Object -ReferenceObject $companyMailDomains -DifferenceObject $antispamPoliciesAllowedSenderDomains -ExcludeDifferent -IncludeEqual).Count | Should -BeExactly 0 -Because "spam filter policies exceptions should not contains company senders"
    }
}

Describe "Checks no domain exceptions in spam filter policies" -Tag "PATRON.Exchange.Antispam.Check-AllowedSenderDomains", "PATRON", "Security", "Exchange", "Antispam", "All"{
    It "Baseline: No domain exceptions in spam filter policies" {
        Add-MtTestResultDetail -Severity 'Medium'
        $hostedContentFilterPolicies.AllowedSenderDomains.Count | Should -BeExactly 0 -Because "no domain exceptions should be in spam filter policies."
    }
}