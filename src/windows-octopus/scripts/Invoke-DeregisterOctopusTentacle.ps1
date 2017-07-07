[CmdletBinding()]
param 
(
  [Parameter(Mandatory = $True)]
  [string]$octopusApiKey,
  [Parameter(Mandatory = $True)]
  [string]$octopusServerUrl,
  [string]$OctopusTentacleDirectory="${env:ProgramFiles}\Octopus Deploy\Tentacle"
)

$ErrorActionPreference = "Stop"
& $OctopusTentacleDirectory\Tentacle.exe "deregister-from" --server $octopusServerUrl --apiKey $octopusApiKey --console
