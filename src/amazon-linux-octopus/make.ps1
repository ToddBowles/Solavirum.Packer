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

$amiRootDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path;

. "$amiRootDirectoryPath\_Find-RootDirectory.ps1";

$rootDirectory = Find-RootDirectory $amiRootDirectoryPath;
$rootDirectoryPath = $rootDirectory.FullName;

. "$rootDirectoryPath\scripts\packer\Functions-Packer.ps1";
. "$rootDirectoryPath\scripts\common\Functions-Hashtables.ps1";

Write-Verbose "Locating the Amazon Linux AMI to base this AMI from"
$searchRegex = "amzn-ami-hvm-[0-9]{4}\.[0-9]{2}\.[0-9]\.[0-9]{8}-x86_64-gp2$";
$ec2ImageDetails = Find-MostRecentAmi -Owner "amazon" -Filters @{"name"="amzn-ami-hvm*";"root-device-type"="ebs";} -Regex $searchRegex -AwsKey $awsKey -AwsSecret $awsSecret -AwsRegion $awsRegion;

$amiParameters = @{
    "source_ami"=$ec2ImageDetails.ImageId;
};

$parameterOverrides = Merge-Hashtables -First $parameterOverrides -Second $amiParameters;

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
