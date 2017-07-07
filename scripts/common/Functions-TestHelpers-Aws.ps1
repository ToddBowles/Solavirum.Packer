. "$here\_Find-RootDirectory.ps1"
$rootDirectory = Find-RootDirectory $here
$rootDirectoryPath = $rootDirectory.FullName

function Get-AwsCredentials
{
    $keyLookup = "ENVIRONMENT_AWS_KEY"
    $secretLookup = "ENVIRONMENT_AWS_SECRET"

    $awsCreds = @{
        AwsKey = (Get-CredentialByKey $keyLookup);
        AwsSecret = (Get-CredentialByKey $secretLookup);
        AwsRegion = "ap-southeast-2";
    }
    return New-Object PSObject -Property $awsCreds
}