$here = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$here\_Find-RootDirectory.ps1"
$rootDirectory = Find-RootDirectory $here
$rootDirectoryPath = $rootDirectory.FullName

Describe "edit-ec2configservice-config" {
    Context "When editing a specific config file" {
        It "No errors are thrown" {
            # Copy the sample file to the working directory
            $workingFilePath = "$here\working\edited-ec2configservice-config.xml";
            $workingFile = New-Item -Path $workingFilePath -ItemType File -Force;
            Copy-Item "$here\sample-ec2configservice-config.xml" $workingFilePath;

            # Run the edit script with a different target
            & "$here\edit-ec2configservice-config.ps1" -fileToEditPath $workingFilePath;
        }
    }
}