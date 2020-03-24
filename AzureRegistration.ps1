Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'

$ServiceInstance = 'BC'
$VaultName = "dynamicsis"
$KeyName = "kappi"
$CertificateThumbprint = '*'
$KeyVaultClientId = '*'
$dnsName = "businesscentral.dynamics.is"
$DisplayName = "${ServiceInstance}-dynamics"
$IdentifierUri = "http://${dnsName}/${DisplayName}"
$ExcelAppDisplayName = "${DisplayName}-Excel"
$ExcelIdentifierUri = "http://${dnsName}/${ExcelAppDisplayName}"

$x509 = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object -Property Thumbprint -EQ $CertificateThumbprint
$CertValue = [System.Convert]::ToBase64String($x509.GetRawCertData())

$KeyVault = Get-AzureRmKeyVault -VaultName $VaultName
if (!$KeyVault) {
    $KeyVault = New-AzureRmKeyVault -VaultName $VaultName -ResourceGroupName $ResourceGroup.ResourceGroupName -Location $ResourceGroup.Location
}

$Key = Get-AzureKeyVaultKey -VaultName $KeyVault.VaultName -Name $KeyName
if (!$Key) {
    $Key = Add-AzureKeyVaultKey -VaultName $KeyVault.VaultName -Name $KeyName -Destination Software 
}

$Application = Get-AzureRmADApplication -DisplayName $DisplayName
if (!$Application) {
    $Application = New-AzureRmADApplication -DisplayName $DisplayName -HomePage "https://${dnsName}/web" -IdentifierUris $IdentifierUri -ReplyUrls "https://${dnsName}/web/SignIn" -CertValue $CertValue -StartDate $x509.NotBefore -EndDate $x509.NotAfter
    $ObjectId = $Application.ObjectId
    Set-AzureRmADApplication -ObjectId $ObjectId -AvailableToOtherTenants $True
    $RequiredResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $ResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.ResourceAccess
    $ResourceAccess.Id = '311a71cc-e848-46a1-bdf8-97ff7156d8e6'
    $ResourceAccess.Type = 'Scope'
    $RequiredResourceAccess.ResourceAccess = $ResourceAccess
    $RequiredResourceAccess.ResourceAppId = '00000002-0000-0000-c000-000000000000'
    Set-AzureADApplication -ObjectId $ObjectId -RequiredResourceAccess $RequiredResourceAccess   
    $Application = Get-AzureRmADApplication -DisplayName $DisplayName
}

$ExcelApplication = Get-AzureRmADApplication -DisplayName $ExcelAppDisplayName
if (!$ExcelApplication) {
    $ExcelApplication = New-AzureRmADApplication -DisplayName $ExcelAppDisplayName -IdentifierUris $ExcelIdentifierUri -ReplyUrls ("https://${dnsName}/web/SignIn","https://az689774.vo.msecnd.net/dynamicsofficeapp/v1.3.0.0/*")
    $ObjectId = $ExcelApplication.ObjectId
    Set-AzureADApplication -ObjectId $ObjectId -Oauth2AllowImplicitFlow $true    
    Set-AzureRmADApplication -ObjectId $ObjectId -AvailableToOtherTenants $True 
    $RequiredResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $ResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.ResourceAccess
    $ResourceAccess.Id = 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
    $ResourceAccess.Type = 'Scope'
    $RequiredResourceAccess.ResourceAccess = $ResourceAccess
    $RequiredResourceAccess.ResourceAppId = '00000003-0000-0000-c000-000000000000'

    $ExcelRequiredResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $ExcelResourceAccess = New-Object -TypeName Microsoft.Open.AzureAD.Model.ResourceAccess
    $ExcelResourceAccess.Id = (Get-AzureADApplication -ObjectId $Application.ObjectId).Oauth2Permissions[0].Id
    $ExcelResourceAccess.Type = 'Scope'
    $ExcelRequiredResourceAccess.ResourceAccess = $ExcelResourceAccess
    $ExcelRequiredResourceAccess.ResourceAppId = $Application.ApplicationId
    Set-AzureADApplication -ObjectId $ObjectId -RequiredResourceAccess ($RequiredResourceAccess,$ExcelRequiredResourceAccess)
    $ExcelApplication = Get-AzureRmADApplication -DisplayName $ExcelAppDisplayName    
}

$ServicePrincipal = Get-AzureRmADServicePrincipal | Where-Object -Property DisplayName -EQ $Application.DisplayName
if (!$ServicePrincipal) {
    $ServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $Application.ApplicationId
}

Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName -ServicePrincipalName $ServicePrincipal.ServicePrincipalNames[1] -PermissionsToKeys encrypt,decrypt,get,list 
Set-AzureRmKeyVaultAccessPolicy -VaultName $KeyVault.VaultName -ApplicationId $Application.ApplicationId -ObjectId $Application.ObjectId -PermissionsToKeys encrypt,decrypt,get,list

Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ClientServicesFederationMetadataLocation -KeyValue "https://login.microsoftonline.com/kappi.onmicrosoft.com/FederationMetadata/2007-06/FederationMetadata.xml"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AppIdUri -KeyValue $IdentifierUri
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName WSFederationLoginEndpoint -KeyValue "https://login.microsoftonline.com/common/wsfed?wa=wsignin1.0%26wtrealm=http://${dnsName}/${DisplayName}%26wreply=https://${dnsName}/web/SignIn"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName DisableTokenSigningCertificateValidation -KeyValue True

Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName EncryptionProvider -KeyValue AzureKeyVault
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureKeyVaultClientId -KeyValue $Application.ApplicationId
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureKeyVaultClientCertificateStoreLocation -KeyValue LocalMachine
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureKeyVaultClientCertificateStoreName -KeyValue My
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureKeyVaultClientCertificateThumbprint -KeyValue $CertificateThumbprint
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureKeyVaultKeyUri -KeyValue $Key.Id

Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName AzureActiveDirectoryClientId -KeyValue "00000000-0000-0000-0000-000000000000"
Set-NAVServerConfiguration -ServerInstance $ServiceInstance -KeyName ExcelAddInAzureActiveDirectoryClientId -KeyValue $ExcelApplication.ApplicationId

Restart-NAVServerInstance -ServerInstance $ServiceInstance
Start-Sleep -Seconds 15
Get-NAVTenant -ServerInstance $ServiceInstance | Sync-NAVTenant -Mode Sync -Force