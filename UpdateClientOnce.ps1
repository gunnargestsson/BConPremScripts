Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'
Import-Module 'C:\Setup\BC14.8.39327-IS\WindowsPowerShellScripts\Cloud\NAVAdministration'
Import-Module 'C:\Setup\BC14.8.39327-IS\WindowsPowerShellScripts\Cloud\NAVRemoteAdministration'
Import-Module WebAdministration
Add-WindowsFeature -Name Web-Http-Redirect 

$ServiceInstance = 'BC'
$DisplayName = "${ServiceInstance}-dynamics"
$dnsName = "businesscentral.dynamics.is"

$wwwRootPath = (Get-Item "HKLM:\SOFTWARE\Microsoft\InetStp").GetValue("PathWWWRoot")
$wwwRootPath = [System.Environment]::ExpandEnvironmentVariables($wwwRootPath)
$clickOnceCodeSigningPfxPasswordAsSecureString = ConvertTo-SecureString -String 'GG8701.a' -AsPlainText -Force
$MageExeLocation = 'C:\AdvaniaGIT\Tools\mage.exe' 
$clickOnceRootPath = Join-Path $wwwRootPath "ClickOnce"
if (!(Test-Path $clickOnceRootPath)) {
    New-Item -Path $clickOnceRootPath -ItemType Directory | Out-Null
}

if (!(Test-Path 'C:\Program Files (x86)\Microsoft Dynamics NAV\140\RoleTailored Client' -PathType Container)) {
    New-Item -ItemType SymbolicLink -Path 'C:\Program Files (x86)\Microsoft Dynamics NAV' -Value 'C:\Program Files (x86)\Microsoft Dynamics 365 Business Central' 
}

foreach ($webSite in (Get-Website)) {
    if ((Split-Path $webSite.PhysicalPath -Parent) -ieq $clickOnceRootPath) { 
        $webSite | Remove-Website 
        Remove-Item -Path $webSite.PhysicalPath -Recurse -Force  -ErrorAction SilentlyContinue 
    }                             
}

$SelectedInstance = New-Object -TypeName PSObject
foreach ($Child in (Get-NAVServerConfiguration -ServerInstance $ServiceInstance -AsXml).DocumentElement.appSettings.ChildNodes) { 
    $SelectedInstance | Add-Member -MemberType NoteProperty -Name $($Child.Attributes["key"].Value) -Value $($Child.Attributes["value"].Value)
}

foreach ($tenant in (Get-NAVTenant -ServerInstance $ServiceInstance)) {
    $companyname = $tenant.DefaultCompany
    $clickOnceDeploymentId = "Kappi-${ServiceInstance}-$($tenant.Id)"
    $clickOnceDirectory = Join-Path $clickOnceRootPath $clickOnceDeploymentId
    Remove-Item -Path $clickOnceDirectory -Recurse -Force -ErrorAction SilentlyContinue
    $webSiteHost = "tengjast$($tenant.Id).dynamics.is"
    $webSiteUrl = "http://$webSiteHost"
    [xml]$clientUserSettings = Get-Content -Path (Join-Path $env:ProgramData ('Microsoft\Microsoft Dynamics NAV\140\ClientUserSettings.config'))
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'Server' -NewValue (Split-Path (Split-Path $SelectedInstance.PublicWinBaseUrl -Parent) -Leaf).Split(':').GetValue(0)
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ClientServicesPort' -NewValue (Split-Path (Split-Path $SelectedInstance.PublicWinBaseUrl -Parent) -Leaf).Split(':').GetValue(1)
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ServerInstance' -NewValue (Split-Path $SelectedInstance.PublicWinBaseUrl -Leaf)
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'DnsIdentity' -NewValue "*.dynamics.is"
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'TenantId' -NewValue $Tenant.Id
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ClientServicesCredentialType' -NewValue AccessControlService
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ServicesCertificateValidationEnabled' -NewValue false
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ServicePrincipalNameRequired' -NewValue false
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'HelpServer' -NewValue 'bc140help.dynamics.is'
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'HelpServerPort' -NewValue 80
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ACSUri' -NewValue "https://login.microsoftonline.com/common/wsfed?wa=wsignin1.0%26wtrealm=http://${dnsName}/${DisplayName}%26wreply=https://${dnsName}/web/SignIn"
    Edit-NAVClientUserSettings -ClientUserSettings $clientUserSettings -KeyName 'ProductName' -NewValue "Business Central frá Kappa ehf."

    Write-Host "Creating ClickOnce Directory..."
    New-ClickOnceDirectory -ClientUserSettings $clientUserSettings -ClickOnceDirectory $clickOnceDirectory    

    Write-Host "Adjusting the application manifest (Microsoft.Dynamics.Nav.Client.exe.manifest)..."
    $applicationFilesDirectory = Join-Path $clickOnceDirectory 'Deployment\ApplicationFiles'
    $applicationManifestFile = Join-Path $applicationFilesDirectory 'Microsoft.Dynamics.Nav.Client.exe.manifest'
    $applicationIdentityName = "$clickOnceDeploymentId application identity"
    $NAVClientFile = (Join-Path $applicationFilesDirectory 'Microsoft.Dynamics.Nav.Client.exe')
    $applicationIdentityVersion = (Get-ItemProperty -Path $NAVClientFile).VersionInfo.FileVersion

    Set-ApplicationManifestFileList `
        -ApplicationManifestFile $applicationManifestFile `
        -ApplicationFilesDirectory $applicationFilesDirectory `
        -MageExeLocation $MageExeLocation

    Set-ApplicationManifestApplicationIdentity `
        -ApplicationManifestFile $applicationManifestFile `
        -ApplicationIdentityName $applicationIdentityName `
        -ApplicationIdentityVersion $applicationIdentityVersion

    Write-Host "Signing the application manifest..."
    Start-ProcessWithErrorHandling -FilePath $MageExeLocation -ArgumentList "-Sign `"$applicationManifestFile`" -CertFile `"C:\AdvaniaGIT\Data\DigiCert-2020.pfx`" -password GG8701.a" 

    Write-Host "Adjusting the deployment manifest (Microsoft.Dynamics.Nav.Client.application)..."
    $deploymentManifestFile = Join-Path $clickOnceDirectory 'Deployment\Microsoft.Dynamics.Nav.Client.application'
    $deploymentIdentityName = "$clickOnceDeploymentId deployment identity" 
    $deploymentIdentityVersion = $applicationIdentityVersion
    $deploymentManifestUrl = ($webSiteUrl + "/Deployment/Microsoft.Dynamics.Nav.Client.application")
    $applicationManifestUrl = ($webSiteUrl + "/Deployment/ApplicationFiles/Microsoft.Dynamics.Nav.Client.exe.manifest")
    $applicationName = "Windows Biðlari fyrir $companyname"

    Set-DeploymentManifestApplicationReference `
        -DeploymentManifestFile $deploymentManifestFile `
        -ApplicationManifestFile $applicationManifestFile `
        -ApplicationManifestUrl $applicationManifestUrl `
        -MageExeLocation $MageExeLocation

    Set-DeploymentManifestSettings `
        -DeploymentManifestFile $deploymentManifestFile `
        -DeploymentIdentityName $deploymentIdentityName `
        -DeploymentIdentityVersion $deploymentIdentityVersion `
        -DeploymentManifestUrl $deploymentManifestUrl `
        -ApplicationPublisher 'Kappi ehf.' `
        -ApplicationName $applicationName

    Write-Host "Signing the deployment manifest..."
    Start-ProcessWithErrorHandling -FilePath $MageExeLocation -ArgumentList "-Sign `"$deploymentManifestFile`" -CertFile `"C:\AdvaniaGIT\Data\DigiCert-2020.pfx`" -password GG8701.a" 

    Write-Host "Putting a web.config file in the Deployment folder, which will tell IIS to allow downloading of .config files etc..."
    Copy-Item -Path (Join-Path $PSScriptRoot NAVClientInstallation.html) -Destination $clickOnceDirectory
    Copy-Item -Path (Join-Path $PSScriptRoot Dynamics365bc.pdf) -Destination $clickOnceDirectory
    $sourceFile = 'C:\Setup\BC14.5.35970-IS\WindowsPowerShellScripts\Cloud\NAVAdministration\ClickOnce\Resources\deployment_web.config'
    $targetFile = Join-Path $clickOnceDirectory 'Deployment\web.config'
    Copy-Item $sourceFile -destination $targetFile
    $sourceFile = 'C:\Setup\BC14.5.35970-IS\WindowsPowerShellScripts\Cloud\NAVAdministration\ClickOnce\Resources\root_web.config'
    $targetFile = Join-Path $clickOnceDirectory 'web.config'
    Copy-Item $sourceFile -destination $targetFile

    Write-Host "Creating the web site..."
    New-Website -Name $clickOnceDeploymentId -PhysicalPath $clickOnceDirectory -HostHeader $webSiteHost -Force
    New-WebBinding -name $clickOnceDeploymentId -Protocol https -HostHeader $webSiteHost -Port 443 -SslFlags 1 

    Write-Host "Creating the web, soap and odata redirect..."
    New-Item -Path (Join-Path $clickOnceDirectory "web") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path (Join-Path $clickOnceDirectory "login") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path (Join-Path $clickOnceDirectory "soap") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path (Join-Path $clickOnceDirectory "odata") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path (Join-Path $clickOnceDirectory "odatav4") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null    
    New-WebVirtualDirectory -Site $clickOnceDeploymentId -Name "Web" -PhysicalPath (Join-Path $clickOnceDirectory "web")                
    New-WebVirtualDirectory -Site $clickOnceDeploymentId -Name "Login" -PhysicalPath (Join-Path $clickOnceDirectory "login")
    New-WebVirtualDirectory -Site $clickOnceDeploymentId -Name "Soap" -PhysicalPath (Join-Path $clickOnceDirectory "soap")
    New-WebVirtualDirectory -Site $clickOnceDeploymentId -Name "OData" -PhysicalPath (Join-Path $clickOnceDirectory "odata")
    New-WebVirtualDirectory -Site $clickOnceDeploymentId -Name "ODataV4" -PhysicalPath (Join-Path $clickOnceDirectory "odataV4")
    Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\${clickOnceDeploymentId}\Web" -Value @{enabled="true";destination="$($SelectedInstance.PublicWebBaseUrl)?tenant=$($Tenant.Id)";exactDestination="true";httpResponseStatus="Permanent"}
    Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\${clickOnceDeploymentId}\login" -Value @{enabled="true";destination="$(($SelectedInstance.PublicWebBaseUrl).replace('/web','/login'))?tenant=$($Tenant.Id)";exactDestination="true";httpResponseStatus="Permanent"}
    Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\${clickOnceDeploymentId}\Soap" -Value @{enabled="true";destination="$($SelectedInstance.PublicSOAPBaseUrl)/Services?tenant=$($Tenant.Id)";exactDestination="true";httpResponseStatus="Permanent"}
    Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\${clickOnceDeploymentId}\OData" -Value @{enabled="true";destination="$(($SelectedInstance.PublicODataBaseUrl).Substring(0,($SelectedInstance.PublicODataBaseUrl).Length - 2))?tenant=$($Tenant.Id)";exactDestination="true";httpResponseStatus="Permanent"}
    Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\${clickOnceDeploymentId}\ODataV4" -Value @{enabled="true";destination="$($SelectedInstance.PublicODataBaseUrl)?tenant=$($Tenant.Id)";exactDestination="true";httpResponseStatus="Permanent"}

    New-Item -Path (Join-Path $clickOnceRootPath "redirect-${ServiceInstance}-$($tenant.Id)") -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    New-Website -Name "redirect-${ServiceInstance}-$($tenant.Id)" -PhysicalPath (Join-Path $clickOnceRootPath "redirect-${ServiceInstance}-$($tenant.Id)") -HostHeader $tenant.AlternateId[0] -Force
    Set-WebConfiguration system.webServer/httpRedirect "IIS:\sites\redirect-${ServiceInstance}-$($tenant.Id)" -Value @{enabled="true";destination="https://$($tenant.AlternateId[0])/Web";exactDestination="true";httpResponseStatus="Permanent"}

}