# Základní tagy — spouštějí se vždy bez ohledu na dostupnost Exchange Online
$baseTags = @(
    # MAESTER framework built-in tests
    #-------------------------------------------------
    #'EIDSCA.AP14'   # Default Authorization Settings - Default User Role Permissions - Allowed to read other users.
    'MS.AAD.5.1'    # Only administrators SHALL be allowed to register applications.
    'MS.AAD.5.2'    # Only administrators SHALL be allowed to consent to applications.
    'MS.AAD.8.1'    # Guest users SHOULD have limited or restricted access to Azure AD directory objects.
    'MS.AAD.8.2'    # Only users with the Guest Inviter role SHOULD be able to invite guest users.
    'MT.1026'       # No hybrid user with permanent role assignment on Control Plane
    #'MT.1061'       # Device registration MFA requirement is enforced only in CA policies

    # PATRON-IT custom tests
    #-------------------------------------------------
    'PATRON.EXO.Check-AntispamDnsSettings'
    'PATRON.Entra.Check-MFAMigrationState'
    'PATRON.Entra.Check-AuthMethods'
    'PATRON.Entra.Check-DomainVerification'
    'PATRON.Entra.Check-NoFederatedDomains'
    'PATRON.Entra.Check-MFARegistrationStatus'
    'PATRON.Entra.Check-SecDefaultOrConditionalAccess'
    'PATRON.Entra.Check-DeviceJoinPermission'
    'PATRON.Entra.Check-AdminConsentRequestSettings'
    'PATRON.Entra.Check-GroupCreatePermission'
    'PATRON.Entra.Check-TenantCreatePermission'
    'PATRON.Entra.Check-PendingRegistrationDevices'
    'PATRON.Entra.Check-ResetUserRiskAfterOnPremPwdChange'
    'PATRON.Entra.Check-BreakglassAccount'
    'PATRON.Entra.Check-DeviceLocalAdminsPolicy'
    'PATRON.Entra.Check-RememberMFADisabled'
    'PATRON.Entra.Check-MFALegacyConfiguredUsers'
)

# Tagy závislé na Exchange Online — přidají se jen pokud je Exchange Online připojen
$exchangeTags = @(
    'MS.EXO.1.1'
    'MS.EXO.3.1'
    'MS.EXO.7.1'
    'MS.EXO.12.1'
    'MS.EXO.12.2'
    'MS.EXO.13.1'
    'MS.EXO.17.1'
    'PATRON.Exchange.Antispam.Check-SpamFilterActions'
    'PATRON.Exchange.Antispam.Check-CompanyDomainSenderException'
    'PATRON.Exchange.Antispam.Check-AllowedSenderDomains'
)
