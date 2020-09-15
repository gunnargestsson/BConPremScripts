$artifactUrl = Get-BCArtifactUrl -type OnPrem -country is -version 14

$ContainerName = 'ExtractApps'
$AppsPath = 'F:\Apps\Microsoft'
$Credential = New-Object System.Management.Automation.PSCredential("gunnargestsson", (ConvertTo-SecureString "myRandomPassword" -AsPlainText -Force));

New-BCContainer -accept_eula -accept_outdated -containerName $ContainerName -artifactUrl $artifactUrl -useTraefik:$false -auth NavUserPassword -useSSL -Credential $Credential -shortcuts None 
Get-BcContainerAppInfo -containerName $ContainerName | Where-Object -Property Publisher -EQ Microsoft | % {
    $AppFileName = Get-BcContainerAppRuntimePackage -containerName $ContainerName -appName $_.Name -Publisher $_.Publisher -appVersion $_.Version -Verbose
    Move-Item -Path $AppFileName -Destination $AppsPath -Force
}
Remove-BCContainer -containerName $ContainerName
