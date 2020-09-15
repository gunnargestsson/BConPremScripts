Get-Service -Name 'MicrosoftDynamicsNavServer*' | Stop-Service

$ServerInstance = "BC160"
$SourcePath = 'F:\Install\Dynamics.365.BC.15953.DK.DVD'
$DestinationPath = 'C:\Program Files\Microsoft Dynamics 365 Business Central\160'

Get-ChildItem -Path $SourcePath -Recurse | Unblock-File

$ConfigFilePath = Join-Path $DestinationPath "Service\CustomSettings.config"
$ConfigFileContent = Get-Content -Encoding UTF8 -Path $ConfigFilePath

$ServiceSourcePath = Join-Path $SourcePath "ServiceTier\program files\Microsoft Dynamics NAV\160\Service"
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


$WebClientSourcePath = Join-Path $SourcePath "WebClient\Microsoft Dynamics NAV\160\Web Client"
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


Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\160\Service\NavAdminTool.ps1'

Get-NAVWebServerInstance | Where-Object -Property Version -Like '16.*' | % {
    $DestinationPath = Split-Path $_.'Configuration File' -Parent
    $ConfigFilePath = $_.'Configuration File'
    $ConfigFileContent = Get-Content -Encoding UTF8 -Path $ConfigFilePath
    $WebConfigFilePath = Join-Path $DestinationPath "web.config"
    $WebConfigFileContent = Get-Content -Encoding UTF8 -Path $WebConfigFilePath
    $FilesUpdates = $true
    try {
        Remove-NAVWebServerInstance -WebServerInstance $_.WebServerInstance
        New-NAVWebServerInstance -WebServerInstance $_.WebServerInstance -ServerInstance $ServerInstance -Server localhost
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


Get-NAVServerInstance | Where-Object -Property Version -Like '16.*' | % {
    $DatabaseServer = Get-NAVServerConfiguration -ServerInstance $_.ServerInstance -KeyName DatabaseServer
    $DatabaseName = Get-NAVServerConfiguration -ServerInstance $_.ServerInstance -KeyName DatabaseName
    Write-Host "Upgrading database ${DatabaseServer}\${DatabaseName} for $($_.ServerInstance)"
    Invoke-NAVApplicationDatabaseConversion -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName -Force
    Set-NAVServerInstance -ServerInstance $_.ServerInstance -Start
}

Get-Service -Name 'MicrosoftDynamicsNavServer*' | Start-Service -ErrorAction SilentlyContinue