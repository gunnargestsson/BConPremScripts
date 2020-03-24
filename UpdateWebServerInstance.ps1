$ServiceInstance = 'BC'
$DisplayName = "${ServiceInstance}-dynamics"
$dnsName = "businesscentral.dynamics.is"

foreach ($instance in (Get-NAVWebServerInstance).WebServerInstance) { Remove-NAVWebServerInstance -WebServerInstance $instance }

New-NAVWebServerInstance `
    -WebServerInstance 'Login' `
    -Server 'localhost' `
    -ClientServicesCredentialType NavUserPassword `
    -ServerInstance $ServiceInstance `
    -ClientServicesPort 7046 `
    -ManagementServicesPort 7045 `
    -AddFirewallException `
    -HelpServer 'bc140help.dynamics.is' `
    -HelpServerPort 80

$navSettings = "C:\inetpub\wwwroot\Login\navsettings.json"
$navWebClientSettings = (Get-Content -Path $navSettings -Encoding UTF8 | Out-String | ConvertFrom-Json).NAVWebSettings
$Properties = Foreach ($ClientSetting in $ClientSettings) { Get-Member -InputObject $ClientSetting -MemberType NoteProperty}
Foreach ($Property in $Properties.Name) {
    $KeyValue = $ExecutionContext.InvokeCommand.ExpandString($ClientSettings.$($Property))
    $navWebClientSettings | Add-Member -MemberType NoteProperty -Name $Property -Value $KeyValue -Force
}
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name PersonalizationEnabled -Value "true"
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name Developer -Value "false"
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name ProductName -Value "Business Central frá Kappa ehf."
$navWebClientSettings.SessionTimeout = "08:00:00"
$newWebClientSettings = New-Object -TypeName PSObject                            
$newWebClientSettings | Add-Member -MemberType NoteProperty -Name NAVWebSettings -Value @()
$newWebClientSettings.NAVWebSettings = $navWebClientSettings
                    
Set-Content -Path $navSettings -Encoding UTF8 -Value ( $newWebClientSettings | ConvertTo-Json )

[xml]$xml = Get-Content "C:\inetpub\wwwroot\Login\web.config" -Encoding UTF8
$xml.SelectSingleNode("//*[@name='Already have tenant specified']").enabled = "true"
$xml.SelectSingleNode("//*[@name='Hostname (without port) to tenant']").enabled = "true"
Set-Content "C:\inetpub\wwwroot\Login\web.config" -Value $xml.OuterXml

New-NAVWebServerInstance `
    -WebServerInstance 'Web' `
    -Server 'localhost' `
    -ClientServicesCredentialType AccessControlService `
    -ServerInstance $ServiceInstance `
    -ClientServicesPort 7046 `
    -ManagementServicesPort 7045 `
    -DnsIdentity '*.dynamics.is' `
    -CertificateThumbprint $CertificateThumbprint `
    -AddFirewallException `
    -HelpServer 'bc140help.dynamics.is' `
    -HelpServerPort 80
    
$navSettings = "C:\inetpub\wwwroot\Web\navsettings.json"
$navWebClientSettings = (Get-Content -Path $navSettings -Encoding UTF8 | Out-String | ConvertFrom-Json).NAVWebSettings
$Properties = Foreach ($ClientSetting in $ClientSettings) { Get-Member -InputObject $ClientSetting -MemberType NoteProperty}
Foreach ($Property in $Properties.Name) {
    $KeyValue = $ExecutionContext.InvokeCommand.ExpandString($ClientSettings.$($Property))
    $navWebClientSettings | Add-Member -MemberType NoteProperty -Name $Property -Value $KeyValue -Force
}
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name PersonalizationEnabled -Value "true"
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name Developer -Value "false"
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name ACSUri -Value "https://login.microsoftonline.com/common/wsfed?wa=wsignin1.0%26wtrealm=http://dynamics.is/${DisplayName}%26wreply=https://${dnsName}/web/SignIn" -Force
$navWebClientSettings | Add-Member -MemberType NoteProperty -Name ProductName -Value "Business Central frá Kappa ehf."
$navWebClientSettings.SessionTimeout = "08:00:00"
$newWebClientSettings = New-Object -TypeName PSObject                            
$newWebClientSettings | Add-Member -MemberType NoteProperty -Name NAVWebSettings -Value @()
$newWebClientSettings.NAVWebSettings = $navWebClientSettings                    
Set-Content -Path $navSettings -Encoding UTF8 -Value ( $newWebClientSettings | ConvertTo-Json )

[xml]$xml = Get-Content "C:\inetpub\wwwroot\Web\web.config" -Encoding UTF8
$xml.SelectSingleNode("//*[@name='Already have tenant specified']").enabled = "true"
$xml.SelectSingleNode("//*[@name='Hostname (without port) to tenant']").enabled = "true"
Set-Content "C:\inetpub\wwwroot\Web\web.config" -Value $xml.OuterXml
