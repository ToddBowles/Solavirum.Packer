function Create-WorkingDirectory
{
    $tempDirectoryName = [Guid]::NewGuid().ToString("N").Substring(0, 10)
    $path = "$rootDirectoryPath\test-working\$tempDirectoryName"
    Write-Verbose "Creating test working directory [$path]"
    return (New-Item -ItemType Directory -Path $path).FullName
}

function Remove-WorkingDirectory
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$path
    )

    try
    {
        Write-Verbose "Removing test working directory [$path]"
        Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
    }
    catch
    {
        Write-Warning "Could not remove working directory at [$path] because of [$_]"
    }
}