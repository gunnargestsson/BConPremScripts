Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'
$ServerInstance = 'BC'

$tenants = Get-NAVTenant -ServerInstance $ServerInstance 
foreach ($tenant in $tenants) {
    Write-Host Tenant: $($tenant.id)
    $installedApps = Get-NAVAppInfo -ServerInstance $ServerInstance -Tenant $tenant.Id -Publisher navision.guru -TenantSpecificProperties
    foreach ($installedApp in $installedApps) {        
        Write-Host Looking for a newer version of app $($installedApp.Name)
        $availableApp = Get-NAVAppInfo -ServerInstance $ServerInstance -Id $installedApp.AppId | Where-Object -Property Version -gt $installedApp.Version | Sort-Object -Property Version | Select-Object -Last 1 -ErrorAction SilentlyContinue
        if ($availableApp) {
            Write-Host Upgrading to version $availableApp.Version 
            Sync-NAVApp -ServerInstance $ServerInstance -Tenant $tenant.id -AppName $installedApp.Name -Version $availableApp.Version 
            Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Tenant $tenant.id -AppName $installedApp.Name -Version $availableApp.Version -Language is-IS
        }
    }
}
