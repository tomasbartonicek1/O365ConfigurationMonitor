$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$customers  = Get-GdapCustomers -ConnectionConfig $connectionConfig

# Načtení required permissions z app registrace; fallback na Config.ps1 (pro případ starší konfigurace)
$manifestPerms = Get-AppRegistrationPermissions -AppId $connectionConfig.AppId
if ($manifestPerms) {
    $requiredGraphPermissions    = $manifestPerms.GraphPermissions
    $requiredExchangePermissions = $manifestPerms.ExchangePermissions
    $permissionsSource = 'app registrace (manifest)'
} elseif ($appConfig.RequiredGraphPermissions -or $appConfig.RequiredExchangePermissions) {
    $requiredGraphPermissions    = $appConfig.RequiredGraphPermissions
    $requiredExchangePermissions = $appConfig.RequiredExchangePermissions
    $permissionsSource = 'Config.ps1'
} else {
    Write-Error "Nepodařilo se načíst požadovaná oprávnění z app registrace (403) a Config.ps1 je neobsahuje. Přidej Application.Read.All do home tenantu, nebo definuj RequiredGraphPermissions v Config.ps1."
    exit 1
}

Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

$customers  = $customers | Where-Object { $_.TenantId -notin $appConfig.ExcludedCustomers }
$customers += $appConfig.AdditionalCustomers

$customerCount  = @($customers).Count
$customerIndex  = 0
$issueCount     = 0

Write-Host "Permissions source            : $permissionsSource"
Write-Host "Required Graph permissions    : $($requiredGraphPermissions -join ', ')"
Write-Host "Required Exchange permissions : $($requiredExchangePermissions -join ', ')"
Write-Host "Required Exchange RBAC roles  : $($appConfig.RequiredExchangeRoles -join ', ')"
Write-Host "Customers to check            : $customerCount"
Write-Host ""

foreach ($customer in $customers) {
    $customerIndex++
    Write-Host "[$customerIndex/$customerCount] $($customer.DisplayName)" -NoNewline

    $exchangeConnected = $false
    $issues = [System.Collections.Generic.List[string]]::new()

    try {
        Connect-MgGraph -ClientId $connectionConfig.AppId -TenantId $customer.TenantId `
            -CertificateThumbprint $connectionConfig.CertificateThumbprint -NoWelcome -ErrorAction Stop | Out-Null

        $permReport = Get-AppPermissionReport `
            -AppId $connectionConfig.AppId `
            -RequiredGraphPermissions $requiredGraphPermissions `
            -RequiredExchangePermissions $requiredExchangePermissions

        if (-not $permReport.AppFound) {
            $issues.Add('APP NOT FOUND IN TENANT')
        } else {
            $missingPerms = @($permReport.MissingGraphPermissions) + @($permReport.MissingExchangePermissions)
            if ($missingPerms.Count -gt 0) {
                $issues.Add("MISSING permissions: $($missingPerms -join ', ')")
            }
        }

        if ($permReport.AppFound -and @($appConfig.RequiredExchangeRoles).Count -gt 0) {
            try {
                $tenantDomain = Get-TenantDefaultDomain $customer.TenantId
                Connect-ExchangeOnline -AppId $connectionConfig.AppId `
                    -CertificateThumbprint $connectionConfig.CertificateThumbprint `
                    -Organization $tenantDomain -ShowBanner:$false -ErrorAction Stop | Out-Null
                $exchangeConnected = $true

                $rbacReport = Get-ExchangeRbacReport `
                    -RequiredRoles $appConfig.RequiredExchangeRoles

                if ($rbacReport.MissingRoles.Count -gt 0) {
                    $issues.Add("MISSING EXO roles: $($rbacReport.MissingRoles -join ', ')")
                }
            } catch {
                $issues.Add("EXO CONNECTION ERROR: $_")
            }
        }

        Write-Host ' — ' -NoNewline
        if ($issues.Count -eq 0) {
            Write-Host 'OK' -ForegroundColor Green
        } else {
            Write-Host ($issues -join ' | ') -ForegroundColor Red
            $issueCount++
        }
    } catch {
        Write-Host ' — ' -NoNewline
        Write-Host "CONNECTION ERROR: $_" -ForegroundColor Red
        $issueCount++
    } finally {
        if ($exchangeConnected) { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null }
        Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
    }
}

Write-Host ""
if ($issueCount -eq 0) {
    Write-Host "All $customerCount customers have all required permissions." -ForegroundColor Green
} else {
    Write-Host "$issueCount/$customerCount customers have missing permissions or connection issues." -ForegroundColor Red
}
