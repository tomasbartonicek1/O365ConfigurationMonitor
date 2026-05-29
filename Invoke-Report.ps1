. "$PSScriptRoot\Config.ps1"
. "$PSScriptRoot\Functions\Results.ps1"

Export-FailureReport -ResultsDirectory $config.ResultsDirectory
