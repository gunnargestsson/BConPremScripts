Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'
Add-Type -Path 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\Microsoft.Dynamics.Nav.Types.dll'
$ServiceInstance = 'BC'
$dnsName = "businesscentral.dynamics.is"


Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ServicesCertificateThumbprint -KeyValue "*"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName PublicODataBaseUrl -KeyValue "https://${dnsName}:7048/bc/ODataV4"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName PublicSOAPBaseUrl -KeyValue "https://${dnsName}:7047/bc/WS"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName PublicWebBaseUrl -KeyValue "https://${dnsName}/web"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName PublicWinBaseUrl -KeyValue "DynamicsNAV://${dnsName}:7046/bc"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ClientServicesCredentialType -KeyValue NavUserPassword
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName EncryptionProvider -KeyValue "AzureKeyVault"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName SupportedLanguages -KeyValue "is-IS;en-US"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName DefaultLanguage -KeyValue "is-IS"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureActiveDirectoryClientSecret -KeyValue ""
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureActiveDirectoryClientCertificateThumbprint -KeyValue "*"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureKeyVaultClientCertificateThumbprint -KeyValue "*"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ApiServicesEnabled -KeyValue true

Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName DefaultClient -KeyValue "Web"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ClientServicesCredentialType -KeyValue NavUserPassword

Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName SOAPServicesSSLEnabled -KeyValue true
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ODataServicesSSLEnabled -KeyValue true

Restart-NAVServerInstance -ServerInstance $ServiceInstance 
Start-Sleep -Seconds 15
Get-NAVTenant -ServerInstance $ServiceInstance | Sync-NAVTenant -Mode Sync -Force
