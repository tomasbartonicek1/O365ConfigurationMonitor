. "$PSScriptRoot\Functions\Types.ps1"
. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Functions\Results.ps1"

Export-FailureReport -ResultsDirectory $appConfig.ResultsDirectory
