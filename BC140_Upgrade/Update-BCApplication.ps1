$SourcePath = 'C:\Setup'
$ServerInstance = 'BC'

Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'

$NavIde = (Get-Item 'C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140\RoleTailored Client\finsql.exe').FullName
. 'C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\140\RoleTailored Client\NavModelTools.ps1' -NavIde $NavIde
$ApplicationUpdate = (Get-ChildItem -Path (Join-Path $SourcePath 'APPLICATION') -Filter *.fob)[0]
$appVersion = (Get-NAVAppInfo -Path ((Get-ChildItem -Path (Join-Path $SourcePath 'extensions') -Filter *.app -Recurse)[0]).FullName).Version.ToString()


if ((Get-NAVServerInstance -ServerInstance $ServerInstance).State -eq "Running") {
    Set-NAVServerInstance -ServerInstance $ServerInstance -Stop -Verbose
}    
$DatabaseServer = Get-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName DatabaseServer
$DatabaseName = Get-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName DatabaseName
$ManagementPort = Get-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName ManagementServicesPort
Write-Host "Upgrading database ${DatabaseServer}\${DatabaseName} for $($ServerInstance)"
Invoke-NAVDatabaseConversion -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName -Verbose
#Invoke-Sqlcmd -ServerInstance $DatabaseServer -Database $DatabaseName -Query "UPDATE [dbo].[`$ndo`$dbproperty] SET [applicationversion] = '$($appVersion.ToString())';" 
Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName EnableSymbolLoadingAtServerStartup -KeyValue true    
Set-NAVServerInstance -ServerInstance $ServerInstance -Start -Verbose
Start-Sleep -Seconds 5
Set-NAVApplication -ServerInstance $ServerInstance -ApplicationVersion $appVersion.ToString() -Force
$command = "ImportObjects`,ImportAction=Overwrite`,SynchronizeSchemaChanges=0`,File=`"$($ApplicationUpdate.FullName)`",generatesymbolreference=1"
$finSqlCommand = "& `"$NavIde`" --% command=${command}`,ServerName=`"${DatabaseServer}`",Database=`"${DatabaseName}`",ntauthentication=1,NavServerName=`"localhost`",NavServerInstance=`"${ServerInstance}`",NavServerManagementport=${ManagementPort} | Out-Null"    
Write-Host "Running command: $finSqlCommand"   
$Result = Invoke-Expression -Command  $finSqlCommand | Out-Null
#$command = "generatesymbolreference"
#$finSqlCommand = "& `"$NavIde`" --% command=${command}`,ServerName=`"${DatabaseServer}`",Database=`"${DatabaseName}`",ntauthentication=1,NavServerName=`"localhost`",NavServerInstance=`"${ServerInstance}`",NavServerManagementport=${ManagementPort} | Out-Null"    
#Write-Host "Running command: $finSqlCommand"   
#$Result = Invoke-Expression -Command  $finSqlCommand | Out-Null
#$command = "compileobjects,generatesymbolreference=1"
#$finSqlCommand = "& `"$NavIde`" --% command=${command}`,ServerName=`"${DatabaseServer}`",Database=`"${DatabaseName}`",ntauthentication=1,NavServerName=`"localhost`",NavServerInstance=`"${ServerInstance}`",NavServerManagementport=${ManagementPort} | Out-Null"    
#Write-Host "Running command: $finSqlCommand"   
#$Result = Invoke-Expression -Command  $finSqlCommand | Out-Null

Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName EnableSymbolLoadingAtServerStartup -KeyValue false
Set-NAVServerInstance -ServerInstance $ServerInstance -Restart -Verbose
Start-Sleep -Seconds 10
Get-NAVTenant -ServerInstance $ServerInstance | Sync-NAVTenant -Mode Sync -Force -Verbose
Get-NAVTenant -ServerInstance $ServerInstance | Start-NAVDataUpgrade -Language is-IS -FunctionExecutionMode Serial -SkipCompanyInitialization -SkipAppVersionCheck -Force
Get-NAVTenant -ServerInstance $ServerInstance | Get-NAVDataUpgrade -Progress    




