. "$PSScriptRoot\Functions\Types.ps1"
. "$PSScriptRoot\Config.ps1"

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
    $htmlFiles = Get-ChildItem -Path $appConfig.ResultsDirectoryHtml -Filter '*.html'

    Write-Host "Uploading $($htmlFiles.Count) file(s) to $($appConfig.SharePointSiteUrl)/$folder"

    foreach ($file in $htmlFiles) {
        $uploadUri = "/v1.0/drives/$driveId/root:/$folder/$($file.Name):/content"
        $body      = [System.IO.File]::ReadAllBytes($file.FullName)

        Invoke-MgGraphRequest -Method PUT -Uri $uploadUri -Body $body -ContentType 'text/html' | Out-Null
        Write-Host "  [OK] $($file.Name)"
    }
} finally {
    Disconnect-MgGraph | Out-Null
}

Write-Host "Done."