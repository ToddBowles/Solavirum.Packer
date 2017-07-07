function EnsurePesterAvailable
{
    [CmdletBinding()]
    param
    (
        [string]$version = "3.3.9"
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    . "$rootDirectoryPath\scripts\common\Functions-Nuget.ps1"

    $package = "Pester"
    $packageDirectoryPath = Nuget-EnsurePackageAvailable -Package $package -Version $version

    if ((Get-Module | Where-Object { $_.Name -eq "Pester" }) -eq $null)
    {
        Write-Verbose "Loading [$package.$version] Module"
        $previousVerbosePreference = $VerbosePreference
        $VerbosePreference = "SilentlyContinue"
        Import-Module "$packageDirectoryPath\tools\Pester.psm1"
        $VerbosePreference = $previousVerbosePreference
    }
}