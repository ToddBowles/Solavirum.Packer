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

Write-Verbose "Locating the Amazon Windows AMI to base this AMI from";
$searchRegex = ".*";
$ec2ImageDetails = Find-MostRecentAmi -Owner "amazon" -Filters @{"name"="Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_SP1_Express**";} -Regex $searchRegex -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion;

$makeArgs = @{
    Ami=$ec2ImageDetails;
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