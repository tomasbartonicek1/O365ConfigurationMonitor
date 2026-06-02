$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
. "$ScriptRoot\Bootstrap.ps1"

$csv = Invoke-WebRequest -Uri $appConfig.TeamMappingUrl -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Csv -Delimiter ';'
$mapping = @{}
foreach ($row in $csv) { $mapping[$row.tenant_id] = $row.team }
$mapping | ConvertTo-Json | Set-Content $appConfig.TeamMappingFile -Encoding UTF8

Write-Host "Team mapping updated: $($mapping.Count) tenants → $($appConfig.TeamMappingFile)"
