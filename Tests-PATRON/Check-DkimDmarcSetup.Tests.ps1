
Describe "Checks all email domain to SPF, DKIM and DMARC setup." -Tag "PATRON.EXO.Check-AntispamDnsSettings", "PATRON", "Email", "Exchange", "Antispam", "SPF", "DKIM", "DMARC", "All" {
    BeforeDiscovery {
        $emailDomains = (Get-MgDomain | Where-Object { $_.SupportedServices -contains 'Email' -and $_.Id -notlike '*.onmicrosoft.com' }).Id
    }

    Context "Domain check" -ForEach $emailDomains {
        BeforeDiscovery {
            $dmarcRecord = [PSCustomObject]@{
                Name = '_dmarc.' + $_
                Type = 'TXT'
            }
    
            try {
                $dmarcQuery = Resolve-DnsName -Name $dmarcRecord.Name -Type $dmarcRecord.Type -ErrorAction SilentlyContinue
                if ($dmarcQuery.Name -eq $dmarcRecord.Name -and $dmarcQuery.Type -eq $dmarcRecord.Type -and $dmarcQuery.Count -eq 1) {
                    $dmarcExists = $true
                }
                else {
                    $dmarcExists = $false
                }
            }
            catch {
                $dmarcExists = $false
            }

            #Check if the parent domain DMARC record exists for each subdomain
            if (-not $dmarcExists) {
                $domainParts = $_.TrimEnd('.') -split '\.'

                if ($domainParts.Length -gt 2) {
                    # Reconstruct parent domains from top-level downwards
                    $parentDomain = $domainParts[1..($domainParts.Length - 1)] -join '.'
                    
                    try {
                        $parentDomainDmarc = ConvertFrom-MailAuthenticationRecordDmarc -DomainName $parentDomain

                        if ($parentDomainDmarc.policySubdomain -in @('quarantine', 'reject'))  {
                            $dmarcExists = $true
                            $dmarc = @{
                                policy = $parentDomainDmarc.policySubdomain;
                            }
                        }
                    }
                    catch {
                        $dmarc = $null
                        $dmarcExists = $false
                    }
                }
            }
        }
        BeforeAll {
            $dmarcRecord = [PSCustomObject]@{
                Name = '_dmarc.' + $_
                Type = 'TXT'
            }
    
            try {
                $dmarcQuery = Resolve-DnsName -Name $dmarcRecord.Name -Type $dmarcRecord.Type -ErrorAction SilentlyContinue
                if ($dmarcQuery.Name -eq $dmarcRecord.Name -and $dmarcQuery.Type -eq $dmarcRecord.Type -and $dmarcQuery.Count -eq 1) {
                    $dmarcExists = $true
                }
                else {
                    $dmarcExists = $false
                }
            }
            catch {
                $dmarcExists = $false
            }

            if ($dmarcExists) {
                try {
                    $dmarc = ConvertFrom-MailAuthenticationRecordDmarc -DomainName $_
                }
                catch {
                    $dmarc = $null
                }
            }
            else {
                $dmarc = $null
            }

            #Check if the parent domain DMARC record exists for each subdomain
            if (-not $dmarcExists) {
                $domainParts = $_.TrimEnd('.') -split '\.'

                if ($domainParts.Length -gt 2) {
                    # Reconstruct parent domains from top-level downwards
                    $parentDomain = $domainParts[1..($domainParts.Length - 1)] -join '.'
                    
                    try {
                        $parentDomainDmarc = ConvertFrom-MailAuthenticationRecordDmarc -DomainName $parentDomain

                        if ($parentDomainDmarc.policySubdomain -in @('quarantine', 'reject'))  {
                            $dmarcExists = $true
                            $dmarc = @{
                                policy = $parentDomainDmarc.policySubdomain;
                            }
                        }
                    }
                    catch {
                        $dmarc = $null
                        $dmarcExists = $false
                    }
                }
            }
        }
    
        It "Baseline: Email domain $_ should have set SPF record with HARD or SOFT fail." {
            Add-MtTestResultDetail -Severity 'Medium'
            $spf = ConvertFrom-MailAuthenticationRecordSpf -DomainName $_

            if ($spf.record -match "-all")
            { $spf = "HARD" }
            elseif ($spf.record -match "~all")
            { $spf = "SOFT" }
            else { $spf = "" }

            $spf | Should -BeIn @('HARD', 'SOFT') -Because ('Email domain ' + $_ + ' should have set SPF record with HARD or SOFT fail')
        }

        # Test replaced by CISA.MS.EXO.3.1 test
        It "Baseline: Email domain $_ should have set DKIM record." -Skip{
            Add-MtTestResultDetail -Severity 'Medium'
            $dkim = ConvertFrom-MailAuthenticationRecordDkim -DomainName $_

            $dkim.record | Should -Not -BeNullOrEmpty -Because ('Email domain ' + $_ + ' should have set DKIM record')
        }

        It "Baseline: Email domain $_ should have set DMARC record (exactly 1)." {
            Add-MtTestResultDetail -Severity 'Medium'
            $dmarcExists | Should -BeTrue -Because ('Email domain ' + $_ + ' should have set DMARC record')
        }

        It "Baseline: DMARC record on domain $_ should be set to REJECT or QUARANTINE action." -Skip:(-not $dmarcExists) {
            Add-MtTestResultDetail -Severity 'Medium'
            $dmarc.policy | Should -BeIn @('quarantine', 'reject') -Because ('DMARC record on domain ' + $_ + ' should be set to REJECT or QUARANTINE action for domain')
        }

        It "Baseline: DMARC record policy for subdomains of domain $_ should be set to REJECT or QUARANTINE action." -Skip:(-not $dmarcExists) {
            Add-MtTestResultDetail -Severity 'Medium'
            $dmarc.policySubdomain | Should -BeIn @('quarantine', 'reject', $null) -Because ('DMARC record policy for subdomains of domain ' + $_ + ' should be set to REJECT or QUARANTINE action')
        }

        It "Baseline: DMARC record percetage on domain $_ should be set to '100' or undefined." -Skip:(-not $dmarcExists) {
            Add-MtTestResultDetail -Severity 'Medium'
            $dmarc.percentage | Should -BeIn @('100', $null) -Because ('DMARC record percetage on domain ' + $_ + '  should be set to 100 or undefined.')
        }
    }
}