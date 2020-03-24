# Login to Azure before executing

Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'
$ServiceInstance = 'BC'
$DatabaseServer = "production"
$CertificateThumbprint = '***'
$VaultName = "dynamicsis"
$KeyName = "kappi"
$DisplayName = "${ServiceInstance}-dynamics"
$dnsName = "businesscentral.dynamics.is"

$KeyVault = Get-AzureRmKeyVault -VaultName $VaultName
$Key = Get-AzureKeyVaultKey -VaultName $KeyVault.VaultName -Name $KeyName
$Application = Get-AzureRmADApplication -DisplayName $DisplayName
$ServicePrincipal = Get-AzureRmADServicePrincipal | Where-Object -Property DisplayName -EQ $Application.DisplayName

$Tenants = @()

$Tenants += @{ID="Setup";Database="Setup Database BC";ClickOnceHost="setup.dynamics.is";DefaultCompany='CRONUS Uppsetning hf.'}
$Tenants += @{ID="Test";Database="Test Database BC";ClickOnceHost="test.dynamics.is";DefaultCompany='CRONUS Tilraunir hf.'}
$Tenants += @{ID="kappi";Database="Kappi BC";ClickOnceHost="kappi.dynamics.is";DefaultCompany='Kappi ehf.'}


$dnsZone = Get-AzureRmDnsZone -Name "dynamics.is" -ResourceGroupName "default-storage-northeurope"

foreach ($Tenant in $Tenants) {
    $TenantExists = Get-NAVTenant -ServerInstance $ServiceInstance -Tenant $Tenant.ID -ErrorAction SilentlyContinue
    if (!$TenantExists) {
        $Param = @{
            ServerInstance = $ServiceInstance
            Id = $Tenant.Id
            DatabaseName = $Tenant.Database
            DatabaseServer = $DatabaseServer
            AlternateId = @($Tenant.ClickOnceHost)
            OverwriteTenantIdInDatabase = $true
            Force = $true
            DefaultCompany = $Tenant.DefaultCompany
            AadTenantId = "kappi.onmicrosoft.com"
            EnvironmentType = "Production"
            }

        
        $Param.EncryptionProvider = "AzureKeyVault"
        $Param.AzureKeyVaultSettings = New-Object Microsoft.Dynamics.Nav.Types.AzureKeyVaultSettings($Application.ApplicationId,"LocalMachine","My",$CertificateThumbprint,$Key.Id)

        if ($Tenant.ID -eq "Setup") {
            $Param.AllowAppDatabaseWrite = $true
        }
        Mount-NAVTenant @Param  
        Sync-NAVTenant -ServerInstance $ServiceInstance -Tenant $Tenant.Id -Mode Sync -Force
        Start-NAVDataUpgrade -ServerInstance $ServiceInstance -Tenant $Tenant.Id -Language is-IS -FunctionExecutionMode Parallel -Force -ContinueOnError -SkipAppVersionCheck -SkipCompanyInitialization
        Get-NAVDataUpgrade -ServerInstance $ServiceInstance -Tenant $Tenant.Id -Progress
        Start-NAVDataUpgrade -ServerInstance $ServiceInstance -Tenant $Tenant.Id -Language is-IS -FunctionExecutionMode Parallel -Force -ContinueOnError -SkipAppVersionCheck
        Get-NAVDataUpgrade -ServerInstance $ServiceInstance -Tenant $Tenant.Id -Progress
        Get-NAVDataUpgrade -ServerInstance $ServiceInstance -Tenant $Tenant.Id -Detailed | Out-GridView
    }
    $DnsRecordSetEntry = Get-AzureRmDnsRecordSet -Name $($Tenant.ClickOnceHost).Split('.').GetValue(0) -ZoneName $DnsZone.Name -ResourceGroupName $DnsZone.ResourceGroupName -RecordType CNAME -ErrorAction SilentlyContinue
    if (!$DnsRecordSetEntry) {
        $DnsRecordSetEntry = New-AzureRmDnsRecordSet -Name $($Tenant.ClickOnceHost).Split('.').GetValue(0) -ZoneName $DnsZone.Name -ResourceGroupName $DnsZone.ResourceGroupName -Ttl 3600 -RecordType CNAME -DnsRecords (New-AzureRmDnsRecordConfig -Cname $dnsName)
    }
    $DnsRecordSetEntry = Get-AzureRmDnsRecordSet -Name "tengjast$($Tenant.Id)" -ZoneName $DnsZone.Name -ResourceGroupName $DnsZone.ResourceGroupName -RecordType CNAME -ErrorAction SilentlyContinue
    if (!$DnsRecordSetEntry) {
        $DnsRecordSetEntry = New-AzureRmDnsRecordSet -Name "tengjast$($Tenant.Id)" -ZoneName $DnsZone.Name -ResourceGroupName $DnsZone.ResourceGroupName -Ttl 3600 -RecordType CNAME -DnsRecords (New-AzureRmDnsRecordConfig -Cname $dnsName)
    }
}
