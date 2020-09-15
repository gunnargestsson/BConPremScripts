Get-Service -Name 'MicrosoftDynamicsNavServer*' | Stop-Service
Start-Sleep -Seconds 10

$SourcePath = 'C:\Setup'
$DestinationPath = 'C:\Program Files\Microsoft Dynamics 365 Business Central\140'
$ClientDestinationPath = 'C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140'

Get-ChildItem -Path $SourcePath -Recurse | Unblock-File

$ConfigFilePath = Join-Path $DestinationPath "Service\CustomSettings.config"
$ConfigFileContent = Get-Content -Encoding UTF8 -Path $ConfigFilePath

$ServiceSourcePath = Join-Path $SourcePath "ServiceTier\program files\Microsoft Dynamics NAV\140\Service"
$FilesUpdates = $true
try {
    Copy-Item -Path $ServiceSourcePath -Destination $DestinationPath -Recurse -Force 
}
catch {
    $FilesUpdates = $false
}
finally {
    Set-Content -Value $ConfigFileContent -Path $ConfigFilePath -Encoding UTF8
    if (-not $FilesUpdates) {throw}
    Write-Host "Service Folder Updated"
}

$ClientSourcePath = Join-Path $SourcePath "RoleTailoredClient\program files\Microsoft Dynamics NAV\140\RoleTailored Client"
$FilesUpdates = $true
try {
    Copy-Item -Path $ClientSourcePath -Destination $ClientDestinationPath -Recurse -Force 
}
catch {
    $FilesUpdates = $false
}
finally {
    if (-not $FilesUpdates) {throw}
    Write-Host "Client Folder Updated"
}


$WebClientSourcePath = Join-Path $SourcePath "WebClient\Microsoft Dynamics NAV\140\Web Client"
$FilesUpdates = $true
try {
    Copy-Item -Path $WebClientSourcePath -Destination $DestinationPath -Recurse -Force 
}
catch {
    $FilesUpdates = $false
}
finally {
    if (-not $FilesUpdates) {throw}
    Write-Host "Web Client Folder Updated"    
}


Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'

Get-NAVWebServerInstance | Where-Object -Property Version -Like 14* | % {
    $DestinationPath = Split-Path $_.'Configuration File' -Parent
    $ConfigFilePath = $_.'Configuration File'
    $ConfigFileContent = Get-Content -Encoding UTF8 -Path $ConfigFilePath
    $WebConfigFilePath = Join-Path $DestinationPath "web.config"
    $WebConfigFileContent = Get-Content -Encoding UTF8 -Path $WebConfigFilePath
    $FilesUpdates = $true
    try {
        Remove-NAVWebServerInstance -WebServerInstance $_.WebServerInstance
        New-NAVWebServerInstance -WebServerInstance $_.WebServerInstance -ServerInstance $_.ServerInstance -Server localhost
    }
    catch {
        $FilesUpdates = $false
    }
    finally {
        Set-Content -Value $ConfigFileContent -Path $ConfigFilePath -Encoding UTF8
        Set-Content -Value $WebConfigFileContent -Path $WebConfigFilePath -Encoding UTF8
        if (-not $FilesUpdates) {throw}
        Write-Host "Web Client $($_.WebServerInstance) at '${DestinationPath}' Updated"    
    }   
}
& {iisreset}
