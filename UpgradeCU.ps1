Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'
Get-NAVTenant BC | % {Get-NAVAppInfo -ServerInstance $_.ServerInstance -Tenant $_.id -TenantSpecificProperties | ConvertTo-Json | Out-File -FilePath "C:\AdvaniaGIT\Workspace\$($_.id).json"}

Get-NAVTenant -ServerInstance BC | % {
    $apps = Get-Content -Path "C:\AdvaniaGIT\Workspace\$($_.id).json" | ConvertFrom-Json
    foreach ($app in ($apps | Where-Object -Property IsInstalled -EQ $true)) {
            Write-Host "Uninstalling $($app.Name) in tenant $($_.id)"
            UnInstall-NAVApp -ServerInstance $_.ServerInstance -Tenant $_.id -AppName $app.Name -Force
            }
 }

Get-NAVTenant -ServerInstance BC | % {Dismount-NAVTenant -ServerInstance $_.ServerInstance -Tenant $_.id -force }

# Stop Instance
# Upgrade Files - Copy CustomSettings.Config file to safety.

# Close this to release the NavAdminTool module
# Copy new Service Instance files
# Copy new Web Client files
# Copy Click Once files
# Copy Client files


# Start Instance Config and update the database name
# Start the service


Get-NAVTenant BC -Tenant kappi | % {Install-NAVApp -ServerInstance $_.ServerInstance -Tenant $_.id -AppName "Advania IS Localization" }
Get-NAVTenant BC -Tenant kappi | % {Sync-NAVApp -ServerInstance $_.ServerInstance -Tenant $_.id -AppName "Advania IS Localization" }
Get-NAVTenant BC -Tenant kappi | % {Start-NAVAppDataUpgrade -ServerInstance $_.ServerInstance -Tenant $_.id -AppName "Advania IS Localization" }

Get-NAVTenant BC -Tenant kappi | % {
    $apps = Get-Content -Path "C:\AdvaniaGIT\Workspace\$($_.id).json" | ConvertFrom-Json
    foreach ($app in ($apps | Where-Object -Property IsInstalled -EQ $true)) {
            Write-Host "Installing $($app.Name) in tenant $($_.id)"
            Install-NAVApp -ServerInstance $_.ServerInstance -Tenant $_.id -AppName $app.Name -ErrorAction SilentlyContinue
            Sync-NAVApp -ServerInstance $_.ServerInstance -Tenant $_.id -AppName $app.Name -ErrorAction SilentlyContinue
            Start-NAVAppDataUpgrade -ServerInstance $_.ServerInstance -Tenant $_.id -AppName $app.Name  -Language is-IS -ErrorAction SilentlyContinue
            }

 }


