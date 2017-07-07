[CmdletBinding()]
param
(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$awsKey,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$awsSecret,
    [string]$awsRegion="ap-southeast-2",
    [string]$config="dev",
    [hashtable]$parameterOverrides,
    [int]$buildNumber=0,
    [switch]$prerelease,
    [string]$prereleaseTag
)

$ErrorActionPreference = "Stop"
$Error.Clear()

$amiRootDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path

. "$amiRootDirectoryPath\_Find-RootDirectory.ps1"

$rootDirectory = Find-RootDirectory $amiRootDirectoryPath
$rootDirectoryPath = $rootDirectory.FullName

. "$rootDirectoryPath\scripts\packer\Functions-Packer.ps1";

$makeArgs = @{
    AwsKey=$awsKey;
    AwsSecret=$awsSecret;
    AwsRegion=$awsRegion;
    AmiRootDirectoryPath=$amiRootDirectoryPath;
    RootDirectoryPath=$rootDirectoryPath;
    Config=$config;
    ParameterOverrides=$parameterOverrides;
    BuildNumber=$buildNumber;
    Prerelease=$prerelease;
    PrereleaseTag=$prereleaseTag;
};

return Make @makeArgs;