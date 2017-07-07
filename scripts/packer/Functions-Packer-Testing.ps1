function Test-Make
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$amiName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $awsCreds,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$makeArgs
    )

    try
    {
        . "$rootDirectoryPath\scripts\common\Functions-Aws.ps1";
        Ensure-AwsPowershellFunctionsAvailable;

        $result = & "$rootDirectoryPath\src\$amiName\make.ps1" @makeArgs;
        $result.Success | Should Be $true;
        $amiId = $result.Manifest.Ami;
        $amiId | Should Not Be $null;

        $ami = Get-EC2Image -ImageId $amiId -Owner "self" -AccessKey $awsCreds.AwsKey -SecretKey $awsCreds.AwsSecret -Region $awsCreds.AwsRegion;
        $ami | Should Not Be $null;
        $ami.Name | Should Match $amiName;
    }
    finally
    {
        if (-not($ami -eq $null) -and ($ami.GetType() -eq [Amazon.EC2.Model.Image]))
        {
            $amiId = $ami.ImageId;
            Write-Verbose "Deleting AMI [$amiId] created as a result of a Test-Make"
            Unregister-EC2Image -ImageId $amiId -AccessKey $awsCreds.AwsKey -SecretKey $awsCreds.AwsSecret -Region $awsCreds.AwsRegion;
        }
    }
}