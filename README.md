# O365 Configuration Monitor

Automatizovaný nástroj pro auditování bezpečnostní konfigurace Microsoft 365 tenantů. Připojuje se k zákaznickým tenantům přes GDAP (Granular Delegated Admin Privileges) a spouští sadu testů z frameworku [Maester](https://maester.dev), která ověřuje soulad s bezpečnostními standardy (CIS, CISA SCuBA, EIDSCA) i vlastními testy PATRON-IT. Výsledky ukládá jako JSON soubory, exportuje do Excelu a HTML reportů nahraných na SharePoint.

---

## Požadavky

- PowerShell 7+
- Přístup k Microsoft 365 home tenantu s GDAP relationshipy k zákazníkům
- Registrovaná aplikace v Entra ID s certifikátovým přihlášením (viz níže)

### Instalace modulů

```powershell
Install-Module -Name Microsoft.Graph
Install-Module -Name Microsoft.Graph.Beta
Install-Module -Name ExchangeOnlineManagement
Install-Module -Name Pester
Install-Module -Name Maester
Install-Module -Name ImportExcel
```

---

## Nastavení (první spuštění)

### 1. Vytvořit certifikát

```powershell
$cert = New-SelfSignedCertificate `
    -Subject "CN=PATRON-Baseline" `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -KeyExportPolicy NonExportable `
    -KeySpec Signature `
    -KeyLength 4096 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter 2029-08-05

Export-Certificate -Cert $cert -FilePath "patron-baseline.cer"
```

Exportovaný `.cer` soubor nahrajte do registrované aplikace v Entra ID (App registrations → Certificates & secrets).

### 2. Vytvořit konfiguraci

Zkopírujte šablonu a vyplňte hodnoty:

```powershell
Copy-Item Config.example.ps1 Config.ps1
```

`Config.ps1` je gitignorovaný — obsahuje thumbprint certifikátu, ID tenantů a e-mailové adresy specifické pro prostředí.

### 3. Stáhnout/aktualizovat Maester testy

```powershell
Import-Module Maester
Update-MaesterTests
```

Tento příkaz naplní složku `Tests-Maester/` aktuálními komunitními testy (CIS, CISA, EIDSCA, ORCA).

---

## Operace

Každý skript lze spustit samostatně — typicky přes Plánovač úloh Windows.

### Aktualizace mapování týmů

```powershell
.\Invoke-UpdateTeamMapping.ps1
```

Stáhne CSV soubor z URL nakonfigurované v `Config.ps1` (`TeamMappingUrl`) a uloží lokální cache `team-mapping.json`. Spouštět před auditem nebo jako samostatnou plánovanou úlohu.

### Audit zákazníků

```powershell
.\Invoke-Audit.ps1
```

Připojí se k home tenantu, načte seznam zákazníků přes GDAP a pro každého zákazníka:
1. Připojí se k MS Graph a Exchange Online
2. Spustí nakonfigurovanou sadu testů (`ConfigTestSuite.ps1`)
3. Uloží výsledky do `<ResultsDirectory>\<tenantId>\Test-Results-<timestamp>.json`
4. Přidá do výsledku pole `Team` z lokální cache mapování

Průběh je vidět v konzoli: `[3/25] Customer Name`.

### Export reportu selhání do Excelu

```powershell
.\Invoke-ReportExcel.ps1
```

Načte poslední výsledky a exportuje všechna selhání do `_summary.xlsx` s formátovanou tabulkou (sloupce: Team, Tenant, Test, Result).

### Generování HTML reportů

```powershell
.\Invoke-ReportHtml.ps1
```

Pro každého tenanta vygeneruje HTML report a souhrnný `_summary.html` přes všechny tenanty. Soubory se uloží do `ResultsDirectoryReport`.

### Nahrání reportů na SharePoint

```powershell
.\Invoke-SharePointUpload.ps1
```

Nahraje všechny HTML a xlsx soubory z `ResultsDirectoryReport` do nakonfigurované SharePoint složky.

### Odeslání denního souhrnu

```powershell
.\Send-DailySummary.ps1
```

Pošle e-mail se souhrnem selhání a změn oproti předchozímu běhu. *(Implementace e-mailu přes MS Graph Send-Mail — zatím stub.)*

### Čištění starých výsledků

```powershell
.\Invoke-CleanupOldReports.ps1
```

Smaže JSON soubory v `ResultsDirectory` starší než `ResultsRetentionDays` dní (výchozí 90). Stáří souboru se detekuje z názvu (`Test-Results-yyyy-MM-dd-HHmmss.json`), ne z metadat filesystému.

### Spustit vše najednou

```powershell
.\Invoke-All.ps1
```

Provede v pořadí: aktualizace týmů → audit → Excel report → HTML reporty → nahrání na SharePoint → čištění starých výsledků.

---

## Konfigurace testů

Sada testů, které se spouštějí, je definována v **`ConfigTestSuite.ps1`** — tento soubor je commitovaný a sdílený napříč prostředími. Obsahuje dvě skupiny tagů:

- `$baseTags` — spouštějí se vždy (Entra ID, základní bezpečnost)
- `$exchangeTags` — spouštějí se jen pokud je Exchange Online dostupný

Při přidání nového testu ho zahrňte do příslušné skupiny v `ConfigTestSuite.ps1`.

---

## Analýza výsledků z konzole

```powershell
$ScriptRoot = (Get-Location).Path
. "$ScriptRoot\Bootstrap.ps1"

# Všechna selhání napříč zákazníky
Get-TestsResultsFailed -ResultsDirectory $appConfig.ResultsDirectory

# Co se změnilo oproti předchozímu běhu
Get-TestsResultsChanged -ResultsDirectory $appConfig.ResultsDirectory
```

---

## Struktura projektu

```
Invoke-Audit.ps1               # Vstupní bod: spustí audit všech zákazníků
Invoke-ReportExcel.ps1         # Vstupní bod: exportuje report selhání do Excelu
Invoke-ReportHtml.ps1          # Vstupní bod: generuje HTML reporty
Invoke-SharePointUpload.ps1    # Vstupní bod: nahraje reporty na SharePoint
Invoke-UpdateTeamMapping.ps1   # Vstupní bod: aktualizuje mapování týmů
Invoke-CleanupOldReports.ps1   # Vstupní bod: smaže staré JSON výsledky
Send-DailySummary.ps1          # Vstupní bod: pošle denní e-mail
Invoke-All.ps1                 # Vstupní bod: spustí vše v pořadí

Bootstrap.ps1                  # Sdílené načtení funkcí a konfigurace
Config.ps1                     # Prostředí-specifická konfigurace (gitignored)
Config.example.ps1             # Šablona konfigurace
ConfigTestSuite.ps1            # Definice testů — které tagy se spouštějí
team-mapping.json              # Cache mapování TenantId→Team (gitignored)

Functions/
  Types.ps1                    # PowerShell třídy (ConnectionConfig)
  Audit.ps1                    # Invoke-TenantAudit + connection helpery
  Customers.ps1                # Get-GdapCustomers (GDAP discovery)
  Results.ps1                  # Analýza výsledků + export
  Email.ps1                    # Send-DailySummaryEmail (stub)

Tests-PATRON/                  # Vlastní testy PATRON-IT
  CAPTemplates/                # Baseline šablony pro Conditional Access policies

Tests-Maester/                 # Komunitní testy (generováno Update-MaesterTests)
  CIS/                         # CIS Microsoft 365 Foundations Benchmark
  CISA/                        # US CISA SCuBA guidelines
  EIDSCA/                      # Entra ID Security Config Analyzer
  ORCA/                        # Exchange Online protection analyzer
```
