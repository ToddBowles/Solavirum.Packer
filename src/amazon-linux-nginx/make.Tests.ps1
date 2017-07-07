$here = Split-Path -Parent $MyInvocation.MyCommand.Path;

. "$here\_Find-RootDirectory.ps1";
$rootDirectory = Find-RootDirectory $here;
$rootDirectoryPath = $rootDirectory.FullName;

. "$rootDirectoryPath\scripts\common\Functions-Credentials.ps1";
. "$rootDirectoryPath\scripts\common\Functions-TestHelpers-Aws.ps1";
. "$rootDirectoryPath\scripts\packer\Functions-Packer-Testing.ps1";

$ami = "amazon-linux-nginx";

Describe $ami -Tags @("Ignore") {
    Context "When running the make" {
        It "No errors are thrown and an AMI is created" {
            $creds = Get-AwsCredentials;
            $makeArgs = @{
                AwsKey=$creds.AwsKey;
                AwsSecret=$creds.AwsSecret;
                AwsRegion=$creds.AwsRegion;
            }

            Test-Make -AmiName $ami -MakeArgs $makeArgs -AwsCreds $creds;
        }
    }
}