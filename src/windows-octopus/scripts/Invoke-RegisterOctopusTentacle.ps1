[CmdletBinding()]
param 
(
    [string]$instanceName = "Tentacle",
    [Parameter(Mandatory = $True)]
    [string]$octopusApiKey,
    [Parameter(Mandatory = $True)]
    [string]$octopusServerUrl,
    [string]$octopusServerThumbprint,
    [Parameter(Mandatory = $True)]
    [string[]]$environments,
    [int]$port = 10933,
    [Parameter(Mandatory = $True)]    
    [string[]]$roles,
    [string]$DefaultApplicationDirectory = "C:\Applications",
    [string]$OctopusTentacleDirectory = "${env:ProgramFiles}\Octopus Deploy\Tentacle"
)

try {
    $ErrorActionPreference = "Stop"

    function _GetMyPrivateIPAddress {
        Write-Verbose "Getting private IP address"
        $ip = (Get-NetAdapter | Get-NetIPAddress | ? AddressFamily -eq 'IPv4').IPAddress
        return $ip
    }

    Write-Verbose "Open port $port on Windows Firewall"
    & netsh.exe advfirewall firewall add rule protocol=TCP dir=in localport=$port action=allow name="Octopus Tentacle: $instanceName"
 
    $tentacleHomeDirectory = "$($env:SystemDrive)\Octopus"
    $tentacleAppDirectory = $DefaultApplicationDirectory
    $tentacleConfigFile = "$($env:SystemDrive)\Octopus\$instanceName\Tentacle.config"
    & $OctopusTentacleDirectory\tentacle.exe create-instance --instance $instanceName --config $tentacleConfigFile --console
    & $OctopusTentacleDirectory\tentacle.exe configure --instance $instanceName --home $tentacleHomeDirectory --console
    & $OctopusTentacleDirectory\tentacle.exe configure --instance $instanceName --app $tentacleAppDirectory --console
    & $OctopusTentacleDirectory\tentacle.exe configure --instance $instanceName --port $port --console
    & $OctopusTentacleDirectory\tentacle.exe new-certificate --instance $instanceName --console
    & $OctopusTentacleDirectory\tentacle.exe configure --instance $instanceName --trust $octopusServerThumbprint --console

    $ipAddress = _GetMyPrivateIPAddress
    $ipAddress = $ipAddress.Trim()
 
    Write-Verbose "Private IP address: $ipAddress"
    Write-Verbose "Configuring and registering Tentacle"

    # OTH change. Customising the name of the tentacle to line up with the AWS instance name (if possible). Will default to the
    # Computer name otherwise.
    $tentacleName = $env:COMPUTERNAME
    try {
        $response = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/instance-id" -UseBasicParsing
        if ($response.StatusCode -eq 200) { $tentacleName = $response.Content }
    }
    catch { }
    $registerArguments = @("register-with", "--instance", $instanceName, "--server", $octopusServerUrl, "--name", $tentacleName, "--publicHostName", $ipAddress, "--apiKey", $octopusApiKey, "--comms-style", "TentaclePassive", "--force", "--console")

    foreach ($environment in $environments) {
        foreach ($e2 in $environment.Split(',')) {
            $registerArguments += "--environment"
            $registerArguments += $e2.Trim()
        }
    }
    foreach ($role in $roles) {
        foreach ($r2 in $role.Split(',')) {
            $registerArguments += "--role"
            $registerArguments += $r2.Trim()
        }
    }

    Write-Verbose "Registering with arguments: $registerArguments"
    & $OctopusTentacleDirectory\tentacle.exe ($registerArguments)
    
    & $OctopusTentacleDirectory\tentacle.exe service --install --instance $instanceName --start --console
    Write-Verbose "Tentacle registration complete"
    exit 0
}
catch {
    Write-Verbose "Registration failed. $_"
    exit 1
}

