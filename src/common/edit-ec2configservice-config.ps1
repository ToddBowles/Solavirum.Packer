[CmdletBinding()]
param
(
    [string]$fileToEditPath="C:\\Program Files\\Amazon\\Ec2ConfigService\\Settings\\Config.xml"
)

$settings = @{
    "Ec2SetPassword"="Enabled";
    "Ec2SetComputerName"="Enabled";
    "Ec2HandleUserData"="Enabled";
    "Ec2DynamicBootVolumeSize"="Enabled";
    "AWS.EC2.Windows.CloudWatch.PlugIn"="Enabled";
};

$xml = [xml](get-content $fileToEditPath);
$xmlElement = $xml.get_DocumentElement();
$xmlElementToModify = $xmlElement.Plugins;

foreach ($setting in $settings.Keys)
{
    $found = $false;
    $value = $settings[$setting];
    foreach ($element in $xmlElementToModify.Plugin)
    {
        if ($element.name -eq $setting)
        {
            $element.State = $value;
            $found = $true;
            break;
        }
    }

    if (-not $found)
    {
        throw "The setting [$setting] could not be found in the configuration file and thus could not be changed";
    }
}

$xml.Save($fileToEditPath);