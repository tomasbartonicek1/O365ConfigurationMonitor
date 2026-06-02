$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

Connect-MgGraph -ClientId $connectionConfig.AppId `
                -TenantId $connectionConfig.HomeTenantId `
                -CertificateThumbprint $connectionConfig.CertificateThumbprint `
                -NoWelcome -ErrorAction Stop

try {
    $uri      = [System.Uri]$appConfig.SharePointSiteUrl
    $hostname = $uri.Host
    $sitePath = $uri.AbsolutePath.Trim('/')

    $site    = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/sites/${hostname}:/${sitePath}"
    $driveId = (Invoke-MgGraphRequest -Method GET -Uri "/v1.0/sites/$($site.id)/drive").id

    $folder    = $appConfig.SharePointFolderPath.Trim('/')
    $files = Get-ChildItem -Path $appConfig.ResultsDirectoryReport | Where-Object { $_.Name -match "\.(xlsx|html)$" }

    Write-Host "Uploading $($files.Count) file(s) to $($appConfig.SharePointSiteUrl)/$folder"

    foreach ($file in $files) {
        $uploadUri = "/v1.0/drives/$driveId/root:/$folder/$($file.Name):/content"
        $body      = [System.IO.File]::ReadAllBytes($file.FullName)

        Invoke-MgGraphRequest -Method PUT -Uri $uploadUri -Body $body -ContentType 'text/html' | Out-Null
        Write-Host "  [OK] $($file.Name)"
    }
} finally {
    Disconnect-MgGraph | Out-Null
}

Write-Host "Done."
