function Get-PackerExecutablePath
{
    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName

    $commonScriptsDirectoryPath = "$rootDirectoryPath\scripts\common"

    . "$commonScriptsDirectoryPath\Functions-Compression.ps1"

    $toolsDirectoryPath = "$rootDirectoryPath\tools"
    $nugetPackagesDirectoryPath = "$toolsDirectoryPath\packages"

    $package = "packer_1.0.0_windows_amd64"

    $expectedDirectory = "$nugetPackagesDirectoryPath\$package"
    if (-not (Test-Path $expectedDirectory))
    {
        $extractedDir = 7Zip-Unzip "$toolsDirectoryPath\no-dist\$package.zip" "$toolsDirectoryPath\packages\$package"
    }

    $executable = "$expectedDirectory\packer.exe"

    return $executable
}

function Execute-Packer
{
    [CmdletBinding()]
    param
    (
        $arguments,
        $logFilePath
    )

    $packer = Get-PackerExecutablePath

    TrySetProxyEnvironmentVariablesFromIESettings

    Write-Verbose "Executing packer from [$packer] with arguments [$arguments] and log file [$logFilePath]";

    $env:PACKER_LOG=1;
    $env:PACKER_LOG_PATH=$logFilePath;

    $captured = @();
    & $packer $arguments | ForEach-Object { 
        $captured += $_;
        Write-Verbose $_;
    }
    $return = $LASTEXITCODE
    if ($return -ne 0)
    {
        throw "Packer execution failed. Exit code [$return]"
    }

    return $captured;
}

function Add-PackerParameter
{
    param
    (
        [array]$initial,
        [string]$name,
        [string]$value
    )

    foreach ($entry in $initial)
    {
        if ($entry -match "^$([Regex]::Escape($name))=")
        {
            throw "A parameter with name [$name] has already been added";
        }
    }

    $initial += "-var"
    $initial += "$name=$value"

    return $initial
}

function TrySetProxyEnvironmentVariablesFromIESettings
{
    Write-Verbose "Attempting to steal proxy settings from IE registry settings"

    try
    {
        $regPath = "hkcu:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\"
        $internetSettings = Get-Item $regPath
        if ($internetSettings.GetValue("ProxyEnable"))
        {
            $proxyServer = $internetSettings.GetValue("ProxyServer")
            if (-not ($proxyServer.StartsWith("http://")))
            {
                $proxyServer = "http://$proxyServer"
            }

            Write-Verbose "Proxy is currently enabled and set to [$proxyServer]. Setting environment variables in the hopes they will be picked up by packer"
            [Environment]::SetEnvironmentVariable("HTTP_PROXY", "$proxyServer", "Process")
            [Environment]::SetEnvironmentVariable("HTTPS_PROXY", "$proxyServer", "Process")
        }
        else
        {
            Write-Verbose "Proxy is not enabled. Check [$regPath\ProxyEnable]"
        }
    }
    catch
    {
        Write-Warning "An error occurred while attempting to get proxy settings from registry"
        Write-Warning $_
    }
}

function New-RunOutputArtifacts
{
    [CmdletBinding()]
    param
    (
        [string]$currentImageDirectoryPath,
        [string]$config
    )

    $runId = (Get-Date).ToString("yyyyMMddHHmmss");
    $outputDirectoryPath = "$currentImageDirectoryPath\runs\$runId\$config";
    if (-not (Test-Path $outputDirectoryPath))
    {
        $outputDirectory = New-Item -ItemType Directory -Path $outputDirectoryPath -Force;
    }

    $manifestFileOutputPath = "$outputDirectoryPath\manifest.json";
    $logFileOutputPath = "$outputDirectoryPath\packer.log";

    return new-object PSObject @{
        Directory=$outputDirectoryPath;
        Manifest=$manifestFileOutputPath;
        Log=$logFileOutputPath;
    };
}

function Find-MostRecentAmi
{
    [CmdletBinding()]
    param
    (
        [string]$regex=".*",
        [ValidateSet("amazon", "self")]
        [string]$owner="self",
        [hashtable]$filters=@{},
        [Parameter(Mandatory=$true)]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [string]$awsRegion
    )

    if ($rootDirectory -eq $null) { throw "rootDirectory script scoped variable not set. Thats bad, its used to find dependencies." }
    $rootDirectoryPath = $rootDirectory.FullName;

    . "$rootDirectoryPath\scripts\common\Functions-Aws.ps1";
    Ensure-AwsPowershellFunctionsAvailable;

    . "$rootDirectoryPath\scripts\common\Functions-Enumerables.ps1";

    $awsFilters = @();
    foreach ($key in $filters.Keys)
    {
        $awsFilters += New-Object Amazon.EC2.Model.Filter -Property @{Name = $key; Value = $filters[$key]};
    }
    
    $ec2ImageDetails = Get-EC2Image -Owner $owner -Filter $awsFilters -AccessKey $awsKey -SecretKey $awsSecret -Region $awsRegion |
        Where-Object { 
            $isMatch = $_.Name -match $regex;
            Write-Verbose "Tested AMI with name [$($_.Name)] against regex [$regex]. Match [$isMatch]";
            return $isMatch;
        } |
        Sort-Object Name -Descending | 
        First

    Write-Verbose "Most recent AMI is [$($ec2ImageDetails.Name)]";

    return $ec2ImageDetails;
}

function Get-Config
{
    [CmdletBinding()]
    param
    (
        [ValidateSet("common", "ami")]
        [string]$scope,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$rootDirectoryPath,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$amiRootDirectoryPath
    )

    if ($scope -eq "common")
    {
        $path = "$rootDirectoryPath\src\common\conf\$name.conf";
    }
    else 
    {
        $path = "$amiRootDirectoryPath\conf\$name.conf";
    }

    if (Test-Path $path)
    {
        Write-Verbose "Loading parameters from config file at [$path]"
        try
        {
            return ConvertFrom-StringData ([System.IO.File]::ReadAllText($path));
        }
        catch
        {
            Write-Warning "An error occurred while attempting to parse the config file at [$path]"
            Write-Warning "You must enter parameters using the KEY=VALUE format, with newlines between each pair."
            Write-Warning "See https://technet.microsoft.com/en-us/library/hh849900.aspx for more examples."
            Write-Warning $_
            return @{};
        }
    }
    else 
    {
        Write-Verbose "The file [$path] did not exist, so no configuration parameters could be loaded from it. This might be bad, or it might not be, its up to you (i.e. did you WANT it to load something from there?)";
        return @{};
    }
}

function Get-Version
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$amiRootDirectoryPath,
        [Parameter(Mandatory=$true)]
        [int]$buildNumber,
        [switch]$prerelease,
        [string]$prereleaseTag
    )

    $version = (ConvertFrom-Json ([System.IO.File]::ReadAllText("$amiRootDirectoryPath\version.json"))).version;
    $version = $version + ".$($buildNumber.ToString())";
    if ($buildNumber -eq 0 -or $prerelease)
    {
        if ([String]::IsNullOrEmpty($prereleaseTag))
        {
            $currentUtcDateTime = (Get-Date).ToUniversalTime();
            $build = $currentUtcDateTime.ToString("yy") + $currentUtcDateTime.DayOfYear.ToString("000");
            $revision = ([int](([int]$currentUtcDateTime.Subtract($currentUtcDateTime.Date).TotalSeconds) / 2)).ToString();
            $prereleaseTag = "$build$revision"
        }

        . "$rootDirectoryPath\scripts\common\Functions-Versioning.ps1";

        $sanitizedSuffix = TrimTo (SanitizeVersionStringForNuget $prereleaseTag) 20;
        $version = $version + "-$sanitizedSuffix";
    }

    Write-Host "##teamcity[buildNumber '$version']";

    return $version;
}

function Make
{
    [CmdletBinding()]
    param
    (
        $ami,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsKey,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsSecret,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$awsRegion,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$amiRootDirectoryPath,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$rootDirectoryPath,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$config,
        [hashtable]$parameterOverrides,
        [Parameter(Mandatory=$true)]
        [int]$buildNumber,
        [switch]$prerelease,
        [string]$prereleaseTag
    )

    # Version the AMI
    $version = Get-Version -amiRootDirectoryPath $amiRootDirectoryPath -buildNumber $buildNumber -prerelease:$prerelease -prereleaseTag $prereleaseTag;

    $artifacts = New-RunOutputArtifacts -Config $config -CurrentImageDirectoryPath $amiRootDirectoryPath;

    $arguments = @()
    $arguments += "build"
    $arguments = Add-PackerParameter -Initial $arguments -Name "aws_access_key" -Value $awsKey;
    $arguments = Add-PackerParameter -Initial $arguments -Name "aws_secret_key" -Value $awsSecret;
    $arguments = Add-PackerParameter -Initial $arguments -Name "aws_region" -Value $awsRegion;
    $arguments = Add-PackerParameter -Initial $arguments -Name "root_directory_path" -Value $rootDirectoryPath;
    $arguments = Add-PackerParameter -Initial $arguments -Name "ami_directory_path" -Value $amiRootDirectoryPath;
    $arguments = Add-PackerParameter -Initial $arguments -Name "manifest_file_output_path" -Value $artifacts.Manifest;
    $arguments = Add-PackerParameter -Initial $arguments -Name "version" -Value $version;

    if ($ami -ne $null)
    {
        $amiId = $ami.ImageId
        $arguments = Add-PackerParameter -Initial $arguments -Name "source_ami" -Value $amiId;
    }

    . "$rootDirectoryPath\scripts\common\Functions-Hashtables.ps1";
    
    Write-Verbose "Initialising Packer parameters from a variety of sources";

    $parameterScopes = @("common", "ami");
    $parameterConfigurations = @("default", $config);

    $parameters = @{};

    foreach ($scope in $parameterScopes)
    {
        foreach ($config in $parameterConfigurations)
        {
            if (-not[String]::IsNullOrEmpty($config))
            {
                Write-Verbose "Attempting to load [$scope] parameters from [$config] file, and merge them with any parameters already loaded";
                $parameters = Merge-Hashtables -First $parameters -Second (Get-Config -Scope $scope -Name $config -AmiRootDirectoryPath $amiRootDirectoryPath -RootDirectoryPath $rootDirectoryPath);
            }
        }
    }

    if ($parameterOverrides -ne $null)
    {
        Write-Verbose "Parameter overrides have been specified as arguments to the Make function. Merging them with the current list of parameters";
        $parameters = Merge-Hashtables -First $parameters -Second $parameterOverrides;
    }

    foreach ($key in $parameters.Keys)
    {
        $arguments = Add-PackerParameter -Initial $arguments -Name $key -Value $parameters[$key];
    }

    $arguments += "$amiRootDirectoryPath\template.json"

    $result = @{
        Config=$config;
        Success=$false;
        Output="NO OUTPUT RECORDED";
        Directory=$artifacts.Directory;
        Manifest=@{
            Source=$artifacts.Manifest;
        };
        Log=@{
            Source=$artifacts.Log;
        };
        Error=$null;
    };

    try
    {
        $output = Execute-Packer -Arguments $arguments -logFilePath $artifacts.Log;
        $result.Manifest.Add("Parsed", (ConvertFrom-Json ([System.IO.File]::ReadAllText($artifacts.Manifest))));
        $result.Manifest.Add("Ami", ($result.Manifest.Parsed.builds[0].artifact_id.Split(":")[1]));
        $result.Success = $true;
        $result.Output = $output;
    }
    catch
    {
        $result.Success = $false;
        $result.Error = $_;
    }

    return new-object PSObject $result;
}