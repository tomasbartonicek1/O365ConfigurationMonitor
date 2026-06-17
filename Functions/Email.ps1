function Get-SeverityBadgeHtml {
    param([string]$Severity)
    $bg = switch ($Severity) {
        'Critical' { '#7B0000' }
        'High'     { '#CC2200' }
        'Medium'   { '#D97706' }
        'Low'      { '#1D4ED8' }
        'Info'     { '#6B7280' }
        default    { '#9CA3AF' }
    }
    $label = if ($Severity) { $Severity } else { 'Unknown' }
    return "<span style=""background:$bg; color:#FFFFFF; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:bold; white-space:nowrap;"">$label</span>"
}

function Get-ResultBadgeHtml {
    param([string]$Result)
    $bg = switch ($Result) {
        'Failed' { '#DC2626' }
        'Passed' { '#16A34A' }
        default  { '#9CA3AF' }
    }
    $label = if ($Result) { $Result } else { '&mdash;' }
    return "<span style=""background:$bg; color:#FFFFFF; padding:2px 8px; border-radius:4px; font-size:11px; font-weight:bold; white-space:nowrap;"">$label</span>"
}

function Build-ChangesTableHtml {
    param([PSCustomObject[]]$Rows)
    if (-not $Rows -or $Rows.Count -eq 0) {
        return '<p style="color:#6B7280; font-size:13px; margin:12px 0;">&#10003;&nbsp; &#381;&#225;dn&#233; zm&#283;ny oprot&#237; p&#345;edchoz&#237;mu auditu.</p>'
    }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<table cellpadding="0" cellspacing="0" style="width:100%; border-collapse:collapse; font-size:13px;">')
    [void]$sb.Append('<tr style="background:#F3F4F6;">')
    foreach ($header in @('Tenant', 'T&#253;m', 'Z&#225;va&#382;nost', 'Test', 'P&#345;edchoz&#237;', 'Nov&#253;')) {
        [void]$sb.Append("<th style=""text-align:left; padding:8px 10px; font-size:11px; color:#6B7280; text-transform:uppercase; letter-spacing:0.05em; border-bottom:2px solid #E5E7EB;"">$header</th>")
    }
    [void]$sb.Append('</tr>')
    $i = 0
    foreach ($row in $Rows) {
        $bg = if ($i % 2 -eq 0) { '#FFFFFF' } else { '#F9FAFB' }
        $tenant  = [System.Net.WebUtility]::HtmlEncode($row.Tenant)
        $team    = [System.Net.WebUtility]::HtmlEncode($row.Team)
        $test    = [System.Net.WebUtility]::HtmlEncode($row.Test)
        [void]$sb.Append("<tr style=""background:$bg;"">")
        [void]$sb.Append("<td style=""padding:8px 10px; border-bottom:1px solid #E5E7EB; vertical-align:top;"">$tenant</td>")
        [void]$sb.Append("<td style=""padding:8px 10px; border-bottom:1px solid #E5E7EB; vertical-align:top; white-space:nowrap;"">$team</td>")
        [void]$sb.Append("<td style=""padding:8px 10px; border-bottom:1px solid #E5E7EB; vertical-align:top;"">$(Get-SeverityBadgeHtml $row.Severity)</td>")
        [void]$sb.Append("<td style=""padding:8px 10px; border-bottom:1px solid #E5E7EB; vertical-align:top;"">$test</td>")
        [void]$sb.Append("<td style=""padding:8px 10px; border-bottom:1px solid #E5E7EB; vertical-align:top;"">$(Get-ResultBadgeHtml $row.PriorResult)</td>")
        [void]$sb.Append("<td style=""padding:8px 10px; border-bottom:1px solid #E5E7EB; vertical-align:top;"">$(Get-ResultBadgeHtml $row.NewResult)</td>")
        [void]$sb.Append('</tr>')
        $i++
    }
    [void]$sb.Append('</table>')
    return $sb.ToString()
}

function Build-DailySummaryHtml {
    param(
        [PSCustomObject[]]$ChangedTests,
        [string]$Date
    )
    $count       = if ($ChangedTests) { $ChangedTests.Count } else { 0 }
    $changesHtml = Build-ChangesTableHtml -Rows $ChangedTests
    $timestamp   = (Get-Date).ToString('yyyy-MM-dd HH:mm')

    return @"
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif; color:#1F2937; background:#F9FAFB; margin:0; padding:0;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#F9FAFB;">
  <tr><td align="center" style="padding:32px 16px;">
    <table width="700" cellpadding="0" cellspacing="0" style="background:#FFFFFF; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,0.1);">
      <tr>
        <td style="background:#1E3A5F; padding:24px 32px; border-radius:8px 8px 0 0;">
          <h1 style="color:#FFFFFF; font-size:20px; margin:0; font-weight:bold;">M365 Security Audit</h1>
          <p style="color:#93C5FD; font-size:13px; margin:8px 0 0 0;">$Date &bull; $count Changes</p>
        </td>
      </tr>
      <tr>
        <td style="padding:24px 32px 32px 32px;">
          <h2 style="font-size:15px; color:#1E3A5F; border-bottom:2px solid #E5E7EB; padding-bottom:8px; margin-top:0;">Zm&#283;ny od posledn&#237;ho auditu</h2>
          $changesHtml
        </td>
      </tr>
      <tr>
        <td style="padding:16px 32px; background:#F3F4F6; border-radius:0 0 8px 8px; font-size:11px; color:#9CA3AF;">
          Generov&#225;no: $timestamp &bull; O365ConfigurationMonitor
        </td>
      </tr>
    </table>
  </td></tr>
</table>
</body>
</html>
"@
}

function Send-DailySummaryEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ConnectionConfig]$ConnectionConfig,
        [Parameter(Mandatory)]
        $AppConfig,
        [Parameter(Mandatory)]
        [PSCustomObject[]]$ChangedTests
    )

    # Requires Mail.Send application permission on the home tenant
    $date     = (Get-Date).ToString('yyyy-MM-dd')
    $count    = if ($ChangedTests) { $ChangedTests.Count } else { 0 }
    $subject  = "M365 Security Audit - $date - $count Changes"
    $htmlBody = Build-DailySummaryHtml -ChangedTests $ChangedTests -Date $date

    $mailBody = @{
        message = @{
            subject      = $subject
            importance   = 'Normal'
            body         = @{
                contentType = 'HTML'
                content     = $htmlBody
            }
            toRecipients = @(
                $AppConfig.EmailRecipients | ForEach-Object {
                    @{ emailAddress = @{ address = $_ } }
                }
            )
        }
        saveToSentItems = $true
    } | ConvertTo-Json -Depth 10

    Connect-MgGraph -ClientId $ConnectionConfig.AppId `
                    -TenantId $ConnectionConfig.HomeTenantId `
                    -CertificateThumbprint $ConnectionConfig.CertificateThumbprint `
                    -NoWelcome -ErrorAction Stop | Out-Null
    try {
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/users/$($AppConfig.EmailSender)/sendMail" `
            -Body $mailBody -ContentType 'application/json'
        Write-Host "Email sent: $subject"
    }
    finally {
        Disconnect-MgGraph | Out-Null
    }
}
