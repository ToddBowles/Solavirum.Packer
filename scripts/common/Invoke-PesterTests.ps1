[CmdletBinding()]
param
(
    [string]$specificTestNames="*",
    [hashtable]$globalCredentialsLookup,
    [string]$rootOutputFileDirectory,
    [string[]]$excludeTags,
    [string[]]$includeTags,
    [string]$searchRootPath,
    [string[]]$testScriptFilePaths,
    [switch]$parallel=$false
)

function Get-PesterTestFiles
{
    param
    (
        [string]$searchRootPath
    )

    $testScriptFilePaths=@();
    Get-ChildItem -Path $searchRootPath | ForEach-Object {
        if ($_ -is [System.IO.DirectoryInfo] -and $_.FullName -notmatch "tools")
        {
            $testScriptFilePaths += Get-PesterTestFiles ($_.FullName);
        }
        else 
        {
            if ($_.Name -match ".*\.tests\.ps1")
            {
                $testScriptFilePaths += $_.FullName;
            }
        }
    };

    return $testScriptFilePaths;
}

$error.Clear()

$ErrorActionPreference = "Stop"

$currentDirectoryPath = Split-Path $script:MyInvocation.MyCommand.Path

. "$currentDirectoryPath\_Find-RootDirectory.ps1";

$rootDirectory = Find-RootDirectory $currentDirectoryPath;
$rootDirectoryPath = $rootDirectory.FullName;

if ($testScriptFilePaths.Length -eq 0)
{
    if ([String]::IsNullOrEmpty($searchRootPath))
    {
        $searchRootPath = $rootDirectoryPath
    }

    Write-Verbose "No list of test files to run was specified. Test files will be automatically located by searching from [$searchRootPath] recursively"
    $testScriptFilePaths = Get-PesterTestFiles $searchRootPath;
}

if ($testScriptFilePaths.Length -eq 0)
{
    Write-Verbose "No test script files were found. Tests have not been executed."
    $resultSummary = @{
        TotalPassed=0;
        TotalFailed=0;
        TotalTime=[Timespan]::Zero;
        AllResults=@()
    }

    return $resultSummary
}

if ($parallel)
{
    Write-Warning "Parallel execution of pester tests was specified. Each test file located will be executed in its own Job, hopefully decreasing the overall time to execute the tests. Maybe."
    Write-Warning "There are [$($testScriptFilePaths.Length)] total test files"

    $allResults = @();

    $script = {
        param
        (
            [string]$scriptFilePath,
            [hashtable]$parameters
        )

        $result = & $scriptFilePath @parameters
        return $result
    }

    $jobs = @();
    foreach ($file in $testScriptFilePaths)
    {
        $arguments = @{
            "-SpecificTestNames"=$specificTestNames;
            "-globalCredentialsLookup"=$globalCredentialsLookup;
            "-rootOutputFileDirectory"=$rootOutputFileDirectory;
            "-excludeTags"=$excludeTags;
            "-includeTags"=$includeTags;
            "-testScriptFilePaths"=@($file);
            "-parallel"=$false;
            "-verbose"=($VerbosePreference -eq "Continue");
        }

        $job = Start-Job -ScriptBlock $script -ArgumentList @("$rootDirectoryPath\scripts\common\Invoke-PesterTests.ps1",$arguments)
        $job.Name = "Pester - [$file]";
        $jobs += $job;
    }

    Write-Verbose "Waiting for [$($jobs.Length)] jobs to complete"
    $waitResult = Wait-Job $jobs

    foreach ($job in $jobs)
    {
        Write-Verbose "------------------------------------"
        Write-Verbose "Results for job [$($job.Name)]"
        $result = Receive-Job $job
        Write-Verbose "------------------------------------"
        foreach ($fileResult in $result.AllResults)
        {
            $allResults += $fileResult
        }
    }
}
else
{
    . "$rootDirectoryPath\scripts\common\Functions-Pester.ps1";
    EnsurePesterAvailable;

    $pesterArgs = @{
        "-Strict"=$true;
        "-Script"=$testScriptFilePaths;
        "-TestName"=$specificTestNames;
        "-PassThru"=$true;
        "-ExcludeTag"=$excludeTags;
    }

    if ($includeTags -ne $null -and $includeTags.Length -gt 0)
    {
        $pesterArgs.Add("-Tags", $includeTags);
    }

    if (-not([string]::IsNullOrEmpty($rootOutputFileDirectory)))
    {
        if ($testScriptFilePaths.Length -gt 1)
        {
            $name = "all";
        }
        else
        {
            $name = [System.IO.Path]::GetFileName($testScriptFilePaths[0]).Replace(".tests.ps1", "");
        }
        $outputFilePath = "$rootOutputFileDirectory\$name.Tests.Powershell.Results.xml"
        $pesterArgs.Add("-OutputFile", $outputFilePath)
        $pesterArgs.Add("-OutputFormat", "NUnitXml")
    }

    $results = Invoke-Pester @pesterArgs

    $augmentedResult = new-object PSObject @{
        "OutputFile"=$outputFilePath;
        "TestResults"=$results;
    };

    $allResults = @($augmentedResult);
}

$passed = 0;
$failed = 0;
$time = new-object TimeSpan(0);
foreach ($result in $allResults)
{
    $passed += $result.TestResults.PassedCount;
    $failed += $result.TestResults.FailedCount;
    $time = $time.Add($result.TestResults.Time);
}

$resultSummary = @{
    TotalPassed=$passed;
    TotalFailed=$failed;
    TotalTime=$time;
    AllResults=$allResults;
}

return $resultSummary