# This script is copied/embedded into TeamCity, into the Build Configuration template that drives all AMI builds.

[CmdletBinding()]
param
(
    [int]$buildNumber,
    [hashtable]$parameterOverrides,
    [string]$devAwsKey,
    [string]$devAwsSecret,
    [string]$devAwsRegion,
    [string]$prodAwsKey,
    [string]$prodAwsSecret,
    [string]$prodAwsRegion,
    [string]$amiName,
    [switch]$teamCity=$true,
    [switch]$isDefaultBranch,
    [string]$branchName
)

function ConvertTo-ParameterOverrides
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$asString
    )

    try
    {
        return ConvertFrom-StringData $asString;
    }
    catch
    {
        Write-Warning "An error occurred while attempting to parse the raw content [$asString]"
        Write-Warning "You must enter parameters using the KEY=VALUE format, with newlines between each pair."
        Write-Warning "See https://technet.microsoft.com/en-us/library/hh849900.aspx for more examples."
        Write-Warning $_
        return @{};
    }
}

function SanitizeStringForTeamCity
{
    param
    (
        [string]$toSanitize
    )
    
    return $toSanitize.Replace("'", "").Replace("[", "(").Replace("]", ")")
}

function Run
{
    param
    (
        [string]$script,
        [string]$environment
    )

    try
    {
        Write-Host "##teamcity[blockOpened name='$environment']";

        if ($environment -eq "dev")
        {
            $awsKey = $devAwsKey;
            $awsSecret = $devAwsSecret;
            $awsRegion =  $devAwsRegion;
        }
        elseif ($environment -eq "prod")
        {
            $awsKey = $prodAwsKey;
            $awsSecret = $prodAwsSecret;
            $awsRegion =  $prodAwsRegion;
        }

        $arguments = @{}
        $arguments.Add("-Verbose", $true)
        $arguments.Add("-AwsKey", $awsKey)
        $arguments.Add("-AwsSecret", $awsSecret)
        $arguments.Add("-AwsRegion", $awsRegion)
        $arguments.Add("-Config", $environment)
        $arguments.Add("-BuildNumber", $buildNumber);
        $arguments.Add("-ParameterOverrides", $parameterOverrides);

        if (-not $isDefaultBranch)
        {
            $arguments.Add("-Prerelease", $true);
            $arguments.Add("-PrereleaseTag", $branchName);
        }

        $output = & $scriptPath @arguments;

        return $output;
    }
    finally
    {
        Write-Host "##teamcity[blockClosed name='$environment']";
    }
}

function _PublishResultAndCheckForFailure
{
    param
    (
        $result
    )

    $config = $result.Config;
    Write-Host "##teamcity[publishArtifacts '$($result.Directory) => $config']";

    if (-not $result.Success)
    {
        $errorStringForTeamCity = SanitizeStringForTeamCity($result.Error.ToString());
        Write-Host "##teamcity[buildProblem description='$config Failed: $errorStringForTeamCity']";
        return $false;
    }
    else 
    {
        return $true;    
    }
}

$ErrorActionPreference = "Stop";

try 
{
    if ($teamCity)
    {
        $buildNumber = [int]::Parse("%build.counter%");
        $isDefaultBranch = [Boolean]::Parse("%teamcity.build.branch.is_default%");
        $branchName = "%teamcity.build.branch%";
        $parameterOverridesString = "%ami.parameters%";
        if (![String]::IsNullOrEmpty($parameterOverridesString))
        {
            $parameterOverrides = ConvertTo-ParameterOverrides -asString $parameterOverridesString;
        }
        $devAwsKey = "%aws.creds.dev.key%";
        $devAwsSecret = "%aws.creds.dev.secret%";
        $devAwsRegion =  "%aws.creds.dev.region%";
        $prodAwsKey = "%aws.creds.prod.key%";
        $prodAwsSecret = "%aws.creds.prod.secret%";
        $prodAwsRegion =  "%aws.creds.prod.region%";
        $amiName = "%ami.name%";
    }

    $scriptPath= ".\src\$amiName\make.ps1";

    if(-not (Test-Path $scriptPath))
    {
        throw "AMI Creation Script should have been at [$scriptPath]. It was not";
    }

    $dev = Run -Script $scriptPath -Environment "dev";
    if (_PublishResultAndCheckForFailure $dev)
    {
        if (-not $isDefaultBranch)
        {
            Write-Warning "Building off a branch. No prod image will be created";
            Write-Host "##teamcity[buildStatus text='($($dev.Config)/$($dev.Manifest.Ami))']";
        }
        else 
        {
            $prod = Run -Script $scriptPath -Environment "prod";
            if (_PublishResultAndCheckForFailure $prod)
            {
                Write-Host "##teamcity[buildStatus text='($($dev.Config)/$($dev.Manifest.Ami)), ($($prod.Config)/$($prod.Manifest.Ami))']";
            }
            else
            {
                Write-Warning "[dev] succeeded but [prod] failed. Deleting the AMI created by [dev]";
                . ".\scripts\common\Functions-Aws.ps1";
                Ensure-AwsPowershellFunctionsAvailable;
                Unregister-EC2Image -ImageId $dev.Manifest.Ami -AccessKey $devAwsKey -SecretKey $devAwsSecret -Region $devAwsRegion;
            }
        }
    }
}
catch 
{
    Write-Warning $_;
    $errorStringForTeamCity = SanitizeStringForTeamCity($_);
    Write-Host "##teamcity[buildProblem description='Critical Error: $errorStringForTeamCity']";
}