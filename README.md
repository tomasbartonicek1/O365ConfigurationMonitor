# O365 Configuration Monitor

Automatizovaný nástroj pro auditování bezpečnostní konfigurace Microsoft 365 tenantů. Připojuje se k zákaznickým tenantům přes GDAP (Granular Delegated Admin Privileges) a spouští sadu testů z frameworku [Maester](https://maester.dev), která ověřuje soulad s bezpečnostními standardy (CIS, CISA SCuBA, EIDSCA) i vlastními testy PATRON-IT. Výsledky ukládá jako JSON soubory pro pozdější analýzu a porovnání.

---

## Požadavky

- PowerShell 7+
- Přístup k Microsoft 365 home tenantu s GDAP relationshipy k zákazníkům
- Registrovaná aplikace v Entra ID s certifikátovým přihlášením (viz níže)

### Instalace modulů

```powershell
Install-Module -Name Microsoft.Graph
Install-Module -Name ExchangeOnlineManagement
Install-Module -Name Maester
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

`Config.ps1` je gitignorovaný — obsahuje thumbprint certifikátu a ID tenantů specifické pro prostředí.

### 3. Stáhnout/aktualizovat Maester testy

```powershell
Import-Module Maester
Update-MaesterTests
```

Tento příkaz naplní složku `Tests-Maester/` aktuálními komunitními testy (CIS, CISA, EIDSCA, ORCA).

---

## Spuštění auditu

```powershell
. .\Connect.ps1
```

Skript se připojí k home tenantu, načte seznam zákazníků přes GDAP, a pro každého zákazníka postupně:
1. Připojí se k MS Graph a Exchange Online
2. Spustí nakonfigurovanou sadu testů (`TestSuite.ps1`)
3. Uloží výsledky do `<ResultsDirectory>\<tenantId>\Test-Results-<timestamp>.json`

Průběh je vidět v konzoli: `[3/25] Customer Name`.

---

## Konfigurace testů

Sada testů, které se spouštějí, je definována v **`TestSuite.ps1`** — tento soubor je commitovaný a sdílený napříč prostředími. Obsahuje dvě skupiny tagů:

- `$baseTags` — spouštějí se vždy (Entra ID, základní bezpečnost)
- `$exchangeTags` — spouštějí se jen pokud je Exchange Online dostupný

Při přidání nového testu ho zahrňte do příslušné skupiny v `TestSuite.ps1`.

---

## Analýza výsledků

Po spuštění jsou k dispozici helper funkce z `ResultHelperFunctions.ps1`:

```powershell
. .\ResultHelperFunctions.ps1

# Všechna selhání napříč zákazníky
Get-TestsResultsFailed -resultsDirectory $config.ResultsDirectory

# Co se změnilo oproti předchozímu běhu
Get-TestsResultsChanged -resultsDirectory $config.ResultsDirectory

# Export do CSV
Get-TestsResultsFailed -resultsDirectory $config.ResultsDirectory |
    Export-Csv -Path "failures.csv" -Encoding utf8BOM
```

---

## Struktura projektu

```
Connect.ps1                  # Hlavní skript — orchestrace celého auditu
Config.ps1                   # Prostředí-specifická konfigurace (gitignored)
Config.example.ps1           # Šablona konfigurace
TestSuite.ps1                # Definice testů — které tagy se spouštějí
ResultHelperFunctions.ps1    # Pomocné funkce pro analýzu výsledků

Tests-PATRON/                # Vlastní testy PATRON-IT
  CAPTemplates/              # Baseline šablony pro Conditional Access policies

Tests-Maester/               # Komunitní testy (generováno Update-MaesterTests)
  CIS/                       # CIS Microsoft 365 Foundations Benchmark
  CISA/                      # US CISA SCuBA guidelines
  EIDSCA/                    # Entra ID Security Config Analyzer
  ORCA/                      # Exchange Online protection analyzer
```
