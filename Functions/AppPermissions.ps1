function Get-AppRegistrationPermissions {
    # Reads required application permissions (type=Role) from the app registration manifest.
    # Requires an active cert-auth connection to the HOME tenant with Application.Read.All or Directory.Read.All.
    # Returns $null if the API is inaccessible (caller should fall back to Config.ps1 values).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId
    )

    try {
        $app = (Invoke-MgGraphRequest -Method GET `
            -Uri "/v1.0/applications?`$filter=appId eq '$AppId'&`$select=requiredResourceAccess"
        ).value | Select-Object -First 1
    } catch {
        if ($_ -match '403' -or $_ -match 'Forbidden' -or $_ -match 'Authorization_RequestDenied') {
            return $null
        }
        throw
    }
    if (-not $app) { return $null }

    $graphSp = (Invoke-MgGraphRequest -Method GET `
        -Uri "/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id,appRoles"
    ).value | Select-Object -First 1
    $exoSp   = (Invoke-MgGraphRequest -Method GET `
        -Uri "/v1.0/servicePrincipals?`$filter=appId eq '00000002-0000-0ff1-ce00-000000000000'&`$select=id,appRoles"
    ).value | Select-Object -First 1

    $graphRoleMap = @{}
    $exoRoleMap   = @{}
    if ($graphSp) { foreach ($r in $graphSp.appRoles) { $graphRoleMap[$r.id] = $r.value } }
    if ($exoSp)   { foreach ($r in $exoSp.appRoles)   { $exoRoleMap[$r.id]   = $r.value } }

    $graphPerms    = [System.Collections.Generic.List[string]]::new()
    $exchangePerms = [System.Collections.Generic.List[string]]::new()

    foreach ($resource in $app.requiredResourceAccess) {
        foreach ($access in $resource.resourceAccess) {
            if ($access.type -ne 'Role') { continue }
            switch ($resource.resourceAppId) {
                '00000003-0000-0000-c000-000000000000' {
                    $name = $graphRoleMap[$access.id]
                    if ($name) { $graphPerms.Add($name) }
                }
                '00000002-0000-0ff1-ce00-000000000000' {
                    $name = $exoRoleMap[$access.id]
                    if ($name) { $exchangePerms.Add($name) }
                }
            }
        }
    }

    return [PSCustomObject]@{
        GraphPermissions    = $graphPerms.ToArray()
        ExchangePermissions = $exchangePerms.ToArray()
    }
}

function Get-AppPermissionReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppId,
        [Parameter(Mandatory)]
        [string[]]$RequiredGraphPermissions,
        [string[]]$RequiredExchangePermissions = @()
    )

    # Find our app's service principal in the currently connected tenant
    $response = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/servicePrincipals?`$filter=appId eq '$AppId'&`$select=id,displayName"
    $ourSp = $response.value | Select-Object -First 1

    if (-not $ourSp) {
        return [PSCustomObject]@{
            AppFound                    = $false
            SpObjectId                  = $null
            GrantedGraphPermissions     = @()
            MissingGraphPermissions     = $RequiredGraphPermissions
            GrantedExchangePermissions  = @()
            MissingExchangePermissions  = $RequiredExchangePermissions
        }
    }

    # Collect all appRoleAssignments (paginovaně)
    $assignments = [System.Collections.Generic.List[object]]::new()
    $uri = "/v1.0/servicePrincipals/$($ourSp.id)/appRoleAssignments"
    do {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri
        foreach ($item in $page.value) { $assignments.Add($item) }
        $uri = $page.'@odata.nextLink'
    } while ($uri)

    # MS Graph SP: 00000003-0000-0000-c000-000000000000
    $graphSpResponse = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id,appRoles"
    $graphSp = $graphSpResponse.value | Select-Object -First 1
    $graphRoleMap = @{}
    foreach ($role in $graphSp.appRoles) { $graphRoleMap[$role.id] = $role.value }

    $grantedGraph = @($assignments | Where-Object { $_.resourceId -eq $graphSp.id } |
        ForEach-Object { $graphRoleMap[$_.appRoleId] } | Where-Object { $_ })
    $missingGraph = @($RequiredGraphPermissions | Where-Object { $_ -notin $grantedGraph })

    $grantedExchange = @()
    $missingExchange = @()

    if ($RequiredExchangePermissions.Count -gt 0) {
        # Exchange Online SP: 00000002-0000-0ff1-ce00-000000000000
        $exoSpResponse = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/servicePrincipals?`$filter=appId eq '00000002-0000-0ff1-ce00-000000000000'&`$select=id,appRoles"
        $exoSp = $exoSpResponse.value | Select-Object -First 1

        if ($exoSp) {
            $exoRoleMap = @{}
            foreach ($role in $exoSp.appRoles) { $exoRoleMap[$role.id] = $role.value }

            $grantedExchange = @($assignments | Where-Object { $_.resourceId -eq $exoSp.id } |
                ForEach-Object { $exoRoleMap[$_.appRoleId] } | Where-Object { $_ })
            $missingExchange = @($RequiredExchangePermissions | Where-Object { $_ -notin $grantedExchange })
        } else {
            $missingExchange = $RequiredExchangePermissions
        }
    }

    return [PSCustomObject]@{
        AppFound                    = $true
        SpObjectId                  = $ourSp.id
        GrantedGraphPermissions     = $grantedGraph
        MissingGraphPermissions     = $missingGraph
        GrantedExchangePermissions  = $grantedExchange
        MissingExchangePermissions  = $missingExchange
    }
}

function Get-ExchangeRbacReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$RequiredRoles
    )

    # Requires active Connect-ExchangeOnline.
    # Role presence is detected by running a representative cmdlet that requires that role.
    # If the cmdlet succeeds, the role is effectively granted; if it throws, the role is missing.
    $roleTests = @{
        'View-Only Organization Management' = { Get-OrganizationConfig -ErrorAction Stop | Out-Null }
    }

    $grantedRoles = [System.Collections.Generic.List[string]]::new()
    $missingRoles = [System.Collections.Generic.List[string]]::new()

    foreach ($role in $RequiredRoles) {
        $test = $roleTests[$role]
        if (-not $test) {
            Write-Warning "No canary test defined for Exchange role '$role' — skipping"
            continue
        }
        try {
            & $test
            $grantedRoles.Add($role)
        } catch {
            $missingRoles.Add($role)
        }
    }

    return [PSCustomObject]@{
        GrantedRoles = $grantedRoles.ToArray()
        MissingRoles = $missingRoles.ToArray()
    }
}
