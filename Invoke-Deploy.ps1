<#
.SYNOPSIS
    Deploys or updates O365ConfigurationMonitor from GitHub.

.DESCRIPTION
    First run (no .git present at DeployPath): performs a shallow clone.
    Subsequent runs: fetches the latest commit and hard-resets, then cleans
    up untracked non-ignored files.

    Files excluded from git (Config.ps1, Tests-Maester/, results*/,
    ConfigEntraTeamMapping.json) are preserved automatically because
    git clean -fd respects .gitignore.

.PARAMETER DeployPath
    Target directory. Defaults to the directory containing this script
    so running from an existing deployment performs an in-place update.
    For a first deploy specify an empty or new directory.

.PARAMETER RepoUrl
    GitHub repository URL. Defaults to the canonical HTTPS URL.

.PARAMETER Branch
    Branch to track. Defaults to 'main'.

.PARAMETER UpdateMaester
    After a successful git update also run Update-MaesterTests to refresh
    the Tests-Maester/ community test suite. Takes several minutes.

.PARAMETER GitHubToken
    GitHub Personal Access Token injected into the HTTPS URL for this run
    only. Not written to disk. Use for private repos or unattended scenarios
    where Git Credential Manager is not available.

.EXAMPLE
    # In-place update (run from the deployed directory):
    .\Invoke-Deploy.ps1

.EXAMPLE
    # First deploy to a new path:
    .\Invoke-Deploy.ps1 -DeployPath 'C:\Tools\O365Monitor'

.EXAMPLE
    # Update code and refresh community Maester tests:
    .\Invoke-Deploy.ps1 -UpdateMaester

.EXAMPLE
    # First deploy to a private repo using a PAT:
    .\Invoke-Deploy.ps1 -DeployPath 'C:\Tools\O365Monitor' -GitHubToken 'ghp_...'
#>

[CmdletBinding()]
param(
    [string]$DeployPath  = '',
    [string]$RepoUrl     = 'https://github.com/martin-haller/O365ConfigurationMonitor.git',
    [string]$Branch      = 'main',
    [switch]$UpdateMaester,
    [string]$GitHubToken
)

$ErrorActionPreference = 'Stop'

# ── Resolve DeployPath (mirrors $ScriptRoot pattern used across this project) ──

if (-not $DeployPath) {
    $DeployPath = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
}
if (-not [System.IO.Path]::IsPathRooted($DeployPath)) {
    $DeployPath = Join-Path (Get-Location).Path $DeployPath
}

# ── Prerequisites ──────────────────────────────────────────────────────────────

Write-Host "`n==> Checking prerequisites" -ForegroundColor Cyan

$gitVersionOutput = git --version 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Git is not installed or not on PATH. Install from https://git-scm.com/"
}
Write-Host "    [OK] $gitVersionOutput"

# ── Build effective repo URL (optional token injection) ───────────────────────

$effectiveRepoUrl = $RepoUrl
if ($GitHubToken) {
    $uriBuilder = [System.UriBuilder]::new($RepoUrl)
    $uriBuilder.UserName = $GitHubToken
    $effectiveRepoUrl = $uriBuilder.Uri.AbsoluteUri
    Write-Host "    [OK] GitHub token injected into URL (not persisted)"
}

# ── Detect first deploy vs update ─────────────────────────────────────────────

$isFirstDeploy = -not (Test-Path (Join-Path $DeployPath '.git'))

# ══════════════════════════════════════════════════════════════════════════════
if ($isFirstDeploy) {
# ══════════════════════════════════════════════════════════════════════════════

    Write-Host "`n==> First deploy -> cloning into: $DeployPath" -ForegroundColor Cyan

    if (Test-Path $DeployPath) {
        $existingCount = (Get-ChildItem $DeployPath -Force | Measure-Object).Count
        if ($existingCount -gt 0) {
            throw "DeployPath '$DeployPath' is non-empty and has no .git directory. " +
                  "Provide an empty or new directory for first deploy."
        }
    }

    git clone --depth 1 --branch $Branch $effectiveRepoUrl $DeployPath
    if ($LASTEXITCODE -ne 0) { throw "git clone failed (exit code $LASTEXITCODE)" }

    $newHead = (git -C $DeployPath rev-parse --short HEAD 2>&1).Trim()
    Write-Host "    [OK] Cloned at $newHead" -ForegroundColor Green

} else {
# ══════════════════════════════════════════════════════════════════════════════
#  Update existing deployment
# ══════════════════════════════════════════════════════════════════════════════

    Write-Host "`n==> Updating existing deployment at: $DeployPath" -ForegroundColor Cyan

    $oldHead = (git -C $DeployPath rev-parse --short HEAD 2>&1).Trim()
    Write-Host "    Current HEAD: $oldHead"

    Write-Host "`n==> Fetching from remote (shallow)" -ForegroundColor Cyan
    git -C $DeployPath fetch --depth 1 origin $Branch
    if ($LASTEXITCODE -ne 0) { throw "git fetch failed (exit code $LASTEXITCODE)" }

    Write-Host "`n==> Resetting to FETCH_HEAD" -ForegroundColor Cyan
    git -C $DeployPath reset --hard FETCH_HEAD
    if ($LASTEXITCODE -ne 0) { throw "git reset failed (exit code $LASTEXITCODE)" }

    Write-Host "`n==> Cleaning untracked files (gitignored files are preserved)" -ForegroundColor Cyan
    git -C $DeployPath clean -fd
    if ($LASTEXITCODE -ne 0) { throw "git clean failed (exit code $LASTEXITCODE)" }

    $newHead = (git -C $DeployPath rev-parse --short HEAD 2>&1).Trim()
    if ($oldHead -eq $newHead) {
        Write-Host "    [OK] Already up to date at $newHead" -ForegroundColor Green
    } else {
        Write-Host "    [OK] $oldHead -> $newHead" -ForegroundColor Green
        git -C $DeployPath log --oneline -1
    }
}

# ── Optional: Update community Maester tests ──────────────────────────────────

if ($UpdateMaester) {
    Write-Host "`n==> Updating Maester community tests (this may take several minutes)..." -ForegroundColor Cyan
    try {
        Import-Module Maester -ErrorAction Stop
        Push-Location $DeployPath
        try   { Update-MaesterTests }
        finally { Pop-Location }
        Write-Host "    [OK] Tests-Maester/ updated" -ForegroundColor Green
    } catch {
        Write-Warning "[WARN] Update-MaesterTests failed: $_"
        Write-Host "    Run manually: Set-Location '$DeployPath'; Import-Module Maester; Update-MaesterTests" -ForegroundColor Yellow
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host ("-" * 60) -ForegroundColor DarkGray
Write-Host "Deploy complete: $DeployPath" -ForegroundColor Green
Write-Host ("-" * 60) -ForegroundColor DarkGray

if ($isFirstDeploy) {
    Write-Host @"

NEXT STEPS (first deploy only):

  1. Create Config.ps1 from the template and fill in all values:
       Copy-Item "$DeployPath\Config.example.ps1" "$DeployPath\Config.ps1"
       notepad "$DeployPath\Config.ps1"

  2. Populate Tests-Maester/ (community test suite, gitignored):
       Set-Location "$DeployPath"
       Import-Module Maester
       Update-MaesterTests

  3. Verify the app registration has the required permissions:
       Set-Location "$DeployPath"
       .\Invoke-CheckAppPermissions.ps1

  4. Schedule the following scripts in Windows Task Scheduler:
       .\Invoke-All.ps1   (or individual Invoke-*.ps1 scripts)
"@ -ForegroundColor Yellow
}

<#
=======================================================================
  ONE-TIME SERVER SETUP  (perform once before running this script)
=======================================================================

1. INSTALL GIT FOR WINDOWS
   https://git-scm.com/  -- select "Add Git to PATH" during install.
   Verify afterwards: git --version

2. CONFIGURE GITHUB CREDENTIALS  (private repo)

   Option A -- Git Credential Manager (interactive, recommended):
     GCM is included with Git for Windows.
     The first clone/fetch opens a browser OAuth flow; credentials are
     stored in Windows Credential Manager and reused automatically.

   Option B -- Personal Access Token, pre-cached (headless / Task Scheduler):
     Create a fine-grained PAT at https://github.com/settings/tokens
     Required permission: Repository -> Contents (read-only)
     Cache it once in Windows Credential Manager:
       cmdkey /generic:git:https://github.com /user:YOUR_GITHUB_USER /pass:ghp_...
     All future git calls authenticate automatically.

   Option C -- PAT per-run (simplest, no caching):
     .\Invoke-Deploy.ps1 -DeployPath 'C:\Tools\O365Monitor' -GitHubToken 'ghp_...'

3. FIRST DEPLOY
   .\Invoke-Deploy.ps1 -DeployPath 'C:\Tools\O365Monitor'

4. CREATE Config.ps1
   Copy-Item 'C:\Tools\O365Monitor\Config.example.ps1' `
             'C:\Tools\O365Monitor\Config.ps1'
   Edit Config.ps1 -- fill in:
     AppId, CertificateThumbprint, HomeTenantId
     SharePointSiteUrl, SharePointFolderPath
     EmailSender, EmailRecipients
     TeamMappingUrl, ExcludedCustomers, etc.

5. POPULATE Tests-Maester/  (community test suite -- NOT from git)
   Set-Location 'C:\Tools\O365Monitor'
   Import-Module Maester
   Update-MaesterTests
   Note: Tests-Maester/ is gitignored. This script never touches it
   unless you pass -UpdateMaester explicitly.

6. SUBSEQUENT UPDATES (run from the deployed directory):
   .\Invoke-Deploy.ps1                  # sync code only
   .\Invoke-Deploy.ps1 -UpdateMaester   # sync code + refresh Tests-Maester/
=======================================================================
#>
