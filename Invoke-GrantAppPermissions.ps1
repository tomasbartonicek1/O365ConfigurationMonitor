param(
    # Zpracuje pouze tohoto zákazníka (TenantId). Bez hodnoty = všichni zákazníci z GDAP.
    [string]$TargetTenantId,
    # Pouze zobrazí co by se udělalo, žádné změny neprovede.
    [switch]$WhatIf,
    # Přepíše RequiredGraphPermissions z Config.ps1.
    [string[]]$GraphPermissions,
    # Přepíše RequiredExchangePermissions z Config.ps1.
    [string[]]$ExchangePermissions
)

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

# ─── Soupis zákazníků + načtení permissions (certifikátová auth) ─────────────

$allCustomers  = Get-GdapCustomers -ConnectionConfig $connectionConfig

# Načtení required permissions z app registrace; fallback na Config.ps1 (pro případ starší konfigurace)
if (-not $GraphPermissions -or -not $ExchangePermissions) {
    $manifestPerms = Get-AppRegistrationPermissions -AppId $connectionConfig.AppId
    if ($manifestPerms) {
        if (-not $GraphPermissions)    { $GraphPermissions    = $manifestPerms.GraphPermissions }
        if (-not $ExchangePermissions) { $ExchangePermissions = $manifestPerms.ExchangePermissions }
        $permissionsSource = 'app registrace (manifest)'
    } elseif ($appConfig.RequiredGraphPermissions -or $appConfig.RequiredExchangePermissions) {
        if (-not $GraphPermissions)    { $GraphPermissions    = $appConfig.RequiredGraphPermissions }
        if (-not $ExchangePermissions) { $ExchangePermissions = $appConfig.RequiredExchangePermissions }
        $permissionsSource = 'Config.ps1'
    } else {
        Write-Error "Nepodařilo se načíst požadovaná oprávnění z app registrace (403) a Config.ps1 je neobsahuje. Přidej Application.Read.All do home tenantu, nebo definuj RequiredGraphPermissions v Config.ps1."
        exit 1
    }
} else {
    $permissionsSource = 'parametr'
}

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

$customers     = $allCustomers | Where-Object { $_.TenantId -notin $appConfig.ExcludedCustomers }
$customers    += $appConfig.AdditionalCustomers

if ($TargetTenantId) {
    $filtered = @($customers | Where-Object { $_.TenantId -eq $TargetTenantId })
    if ($filtered.Count -eq 0) {
        $filtered = @([PSCustomObject]@{ TenantId = $TargetTenantId; DisplayName = $TargetTenantId })
    }
    $customers = $filtered
}

$customerCount = @($customers).Count

Write-Host "App ID               : $($connectionConfig.AppId)"
Write-Host "Permissions zdroj    : $permissionsSource"
Write-Host "Graph permissions    : $($GraphPermissions -join ', ')"
Write-Host "Exchange permissions : $($ExchangePermissions -join ', ')"
if ($WhatIf) { Write-Host "[WHATIF — žádné změny nebudou provedeny]" -ForegroundColor Yellow }
Write-Host "Zákazníků celkem     : $customerCount"
Write-Host ""

# ─── FÁZE 1: Audit (certifikát, tichá) ────────────────────────────────────────

Write-Host "=== FÁZE 1: Audit oprávnění ===" -ForegroundColor Cyan
Write-Host ""

$auditResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$auditIndex   = 0

foreach ($customer in $customers) {
    $auditIndex++
    Write-Host "[$auditIndex/$customerCount] $($customer.DisplayName)" -NoNewline

    try {
        Connect-MgGraph -ClientId $connectionConfig.AppId -TenantId $customer.TenantId `
            -CertificateThumbprint $connectionConfig.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null

        $report = Get-AppPermissionReport `
            -AppId $connectionConfig.AppId `
            -RequiredGraphPermissions $GraphPermissions `
            -RequiredExchangePermissions $ExchangePermissions

        $missingCount = $report.MissingGraphPermissions.Count + $report.MissingExchangePermissions.Count

        Write-Host ' — ' -NoNewline
        if (-not $report.AppFound) {
            Write-Host 'app nenalezena v tenantu' -ForegroundColor Yellow
        } elseif ($missingCount -gt 0) {
            $missingList = ($report.MissingGraphPermissions + $report.MissingExchangePermissions) -join ', '
            Write-Host "chybí: $missingList" -ForegroundColor Yellow
        } else {
            Write-Host 'vše v pořádku' -ForegroundColor Gray
        }

        $auditResults.Add([PSCustomObject]@{
            Customer                   = $customer
            AppFound                   = $report.AppFound
            MissingGraphPermissions    = $report.MissingGraphPermissions
            MissingExchangePermissions = $report.MissingExchangePermissions
            NeedsWork                  = (-not $report.AppFound) -or ($missingCount -gt 0)
            AuditError                 = $null
        })
    } catch {
        Write-Host ' — ' -NoNewline
        Write-Host "CHYBA PŘIPOJENÍ: $_" -ForegroundColor Red
        $auditResults.Add([PSCustomObject]@{
            Customer                   = $customer
            AppFound                   = $false
            MissingGraphPermissions    = @()
            MissingExchangePermissions = @()
            NeedsWork                  = $false
            AuditError                 = "$_"
        })
    } finally {
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
}

$needsWork   = @($auditResults | Where-Object { $_.NeedsWork })
$alreadyOk   = @($auditResults | Where-Object { -not $_.NeedsWork -and -not $_.AuditError })
$auditErrors = @($auditResults | Where-Object { $_.AuditError })

Write-Host ""
$auditSummary = "$($needsWork.Count) tenant(ů) potřebuje úpravu, $($alreadyOk.Count) je v pořádku"
if ($auditErrors.Count -gt 0) { $auditSummary += ", $($auditErrors.Count) chyba(y) připojení" }
Write-Host "Výsledek auditu: $auditSummary"
Write-Host ""

if ($needsWork.Count -eq 0) {
    Write-Host "Všichni zákazníci mají všechna požadovaná oprávnění." -ForegroundColor Green
    return
}

# ─── FÁZE 2: Otevření admin consent URL v prohlížeči ─────────────────────────

Write-Host "=== FÁZE 2: Admin consent URL ===" -ForegroundColor Cyan
Write-Host ""

if ($WhatIf) {
    Write-Host "[WHATIF — URL budou zobrazeny, ale prohlížeč se neotevře]" -ForegroundColor Yellow
    Write-Host ""
}

$consentIndex = 0
foreach ($item in $needsWork) {
    $consentIndex++
    $missingList  = ($item.MissingGraphPermissions + $item.MissingExchangePermissions) -join ', '
    $consentUrl   = "https://login.microsoftonline.com/$($item.Customer.TenantId)/adminconsent?client_id=$($connectionConfig.AppId)"

    Write-Host "[$consentIndex/$($needsWork.Count)] $($item.Customer.DisplayName)" -ForegroundColor Cyan
    if ($item.AppFound) {
        Write-Host "  Chybí: $missingList"
    } else {
        Write-Host "  App nenalezena — consent ji vytvoří a udělí všechna oprávnění"
    }
    Write-Host "  $consentUrl"
    Write-Host ""

    if (-not $WhatIf) {
        Start-Process $consentUrl
    }
}

Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "WHATIF: $($needsWork.Count) URL vygenerováno, prohlížeč nebyl otevřen." -ForegroundColor Yellow
} else {
    Write-Host "$($needsWork.Count) záložka(ek) otevřeno v prohlížeči." -ForegroundColor Green
    Write-Host "V každé záložce se přihlaste jako Global Administrator a klikněte Přijmout."
    Write-Host "Po dokončení spusťte Invoke-CheckAppPermissions.ps1 pro ověření."
}
