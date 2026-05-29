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

## Running the Audit

```powershell
# Copy and fill in Config.example.ps1 → Config.ps1 before running
. .\Connect.ps1
```

`Connect.ps1` loads `Config.ps1`, authenticates to the home tenant with a certificate, discovers GDAP customer tenants, and iterates over them running Maester tests.

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

### Entry Points

| File | Role |
|------|------|
| `Config.ps1` | Runtime config: cert thumbprint, tenant IDs, app ID, result dirs, customer lists — **gitignored, env-specific** |
| `Config.example.ps1` | Configuration template |
| `TestSuite.ps1` | Which Maester test tags to run — **committed, shared across all environments** |
| `Connect.ps1` | Main orchestrator: auth → GDAP discovery → per-tenant test loop → JSON output |
| `ResultHelperFunctions.ps1` | Helper functions for analysing saved JSON results (failed/changed tests) |

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
Config.ps1 → Connect.ps1
  └─ Authenticate (certificate) to home tenant
  └─ List GDAP customers (Graph API)
  └─ For each customer tenant:
       ├─ Connect-MgGraph (delegated)
       ├─ Connect-ExchangeOnline (delegated)
       ├─ Invoke-Maester -Tag <tags from Config.ps1>
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
