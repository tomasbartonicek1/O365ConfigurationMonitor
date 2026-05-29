# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShell-based Microsoft 365 compliance audit system. Connects to multiple customer tenants via GDAP (Granular Delegated Admin Privileges) and runs Maester/Pester test suites to validate security configurations. Results are saved as JSON per tenant.

## Prerequisites & Module Installation

```powershell
Install-Module -Name Microsoft.Graph
Install-Module -Name ExchangeOnlineManagement
Install-Module -Name Maester
```

## Entry-Point Scripts

Each script is independently callable from Task Scheduler:

| Script | Purpose |
|--------|---------|
| `Invoke-Audit.ps1` | Run full audit of all tenants → save JSON results |
| `Invoke-Report.ps1` | Export failure report to CSV from saved results |
| `Send-DailySummary.ps1` | Send daily summary email (MS Graph Send-Mail) |
| `Invoke-All.ps1` | Run all three operations in sequence |

## Running Tests (Maester interactive)

```powershell
Connect-Maester          # Authenticate interactively
Invoke-Maester           # Run all tests
Invoke-Maester -Tag PATRON  # Run only PATRON-IT custom tests
```

## Updating Maester & Community Tests

```powershell
Update-Module Maester -Force
Import-Module Maester
Update-MaesterTests
```

## Architecture

### Key Files

| File | Role |
|------|------|
| `Config.ps1` | Runtime config: cert thumbprint, tenant IDs, app ID, result dirs, email — **gitignored, env-specific** |
| `Config.example.ps1` | Configuration template |
| `TestSuite.ps1` | Which Maester test tags to run — **committed, shared across all environments** |
| `Functions/Audit.ps1` | `Invoke-TenantAudit` + connection helpers (`Get-TenantDefaultDomain`, `Write-Result`, etc.) |
| `Functions/Results.ps1` | `Get-TestsResultsFailed`, `Get-TestsResultsChanged`, `Export-FailureReport` |
| `Functions/Email.ps1` | `Send-DailySummaryEmail` stub (MS Graph Send-Mail, not yet implemented) |

### Test Suites

**`Tests-PATRON/`** — Custom PATRON-IT tests (always maintained here):
- CA policy baselines compared against JSON templates in `Tests-PATRON/CAPTemplates/`
- Authentication method policies (FIDO2, Authenticator, TAP)
- Exchange anti-spam, DKIM/DMARC, audit log, legacy MFA, MFA registration
- Entra device settings, external collaboration, directory sync

**`Tests-Maester/`** — Standard compliance frameworks (auto-updated by `Update-MaesterTests`):
- `CIS/` — CIS Microsoft 365 Foundations Benchmark
- `CISA/` — US CISA SCuBA guidelines
- `EIDSCA/` — Entra ID Security Config Analyzer
- `ORCA/` — Exchange Online protection analyzer
- `Custom/` — Tenant-specific overrides
- `maester-config.json` — Severity overrides for 1400+ community tests

### Data Flow

```
Config.ps1 + TestSuite.ps1 → Invoke-Audit.ps1
  └─ Invoke-TenantAudit (Functions/Audit.ps1)
       ├─ Authenticate (certificate) to home tenant
       ├─ List GDAP customers (Graph API)
       └─ For each customer:
            ├─ Connect-MgGraph (delegated)
            ├─ Connect-ExchangeOnline (delegated)
            ├─ Invoke-Maester -Tag <tags from TestSuite.ps1>
            └─ Save → test-results/{tenantId}/Test-Results-{timestamp}.json
```

### Test Result JSON Schema

```json
{
  "Result": "Failed|Passed",
  "FailedCount": N, "PassedCount": N, "SkippedCount": N, "NotRunCount": N,
  "TenantId": "UUID", "TenantName": "string",
  "LoadedModules": [...], "PowerShellInfo": {...}
}
```
