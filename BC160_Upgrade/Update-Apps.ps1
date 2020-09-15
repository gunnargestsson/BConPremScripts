Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\160\Service\NavAdminTool.ps1'

$ServerInstance = "BC160Pinstrup"
$SourcePath = 'F:\Install\Dynamics.365.BC.15953.DK.DVD'
$appsOnDVD = Get-ChildItem -Path (Join-Path $SourcePath 'Applications') -Filter *.app -Recurse
$appInfoOnDVD = @()
foreach ($appOnDVD in $appsOnDVD) {
    $appInfo = Get-NAVAppInfo -Path $appOnDVD.FullName
    $appInfo | Add-Member -MemberType NoteProperty -Name FullName -Value $appOnDVD.FullName
    $appInfoOnDVD += $appInfo
}

$publishedApps = Get-NAVAppInfo -ServerInstance $ServerInstance | Where-Object -Property Publisher -EQ Microsoft
foreach ($publishedApp in $publishedApps) {
    Write-Host Looking for upgraded app named: $($publishedApp.Name)
    $appOnDVD = $appInfoOnDVD | Where-Object -Property Publisher -EQ $publishedApp.Publisher | Where-Object -Property Name -EQ $publishedApp.Name | Where-Object -Property Version -GT $publishedApp.Version
    if (-not ($publishedApps | Where-Object -Property Publisher -EQ $appOnDVD.Publisher | Where-Object -Property Name -EQ $appOnDVD.Name | Where-Object -Property Version -EQ $appOnDVD.Version) -and $appOnDVD) {
        Write-Host "Publising upgrade $($publishedApp.Version) -> $($appOnDVD.Version)"
        Publish-NAVApp -ServerInstance $ServerInstance -Path $appOnDVD.FullName -Scope Global -ErrorAction SilentlyContinue
    } else {
        Write-Host No upgrade found for $($publishedApp.Version)
    }
}

$publishedApps = Get-NAVAppInfo -ServerInstance $ServerInstance | Where-Object -Property Publisher -EQ Microsoft
foreach ($publishedApp in $publishedApps) {
    Write-Host Looking for upgraded app named: $($publishedApp.Name)
    $appOnDVD = $appInfoOnDVD | Where-Object -Property Publisher -EQ $publishedApp.Publisher | Where-Object -Property Name -EQ $publishedApp.Name | Where-Object -Property Version -GT $publishedApp.Version
    if (-not ($publishedApps | Where-Object -Property Publisher -EQ $appOnDVD.Publisher | Where-Object -Property Name -EQ $appOnDVD.Name | Where-Object -Property Version -EQ $appOnDVD.Version) -and $appOnDVD) {
        Write-Host "Publising upgrade $($publishedApp.Version) -> $($appOnDVD.Version)"
        Publish-NAVApp -ServerInstance $ServerInstance -Path $appOnDVD.FullName -Scope Global 
    } else {
        Write-Host No upgrade found for $($publishedApp.Version)
    }
}

$tenants = Get-NAVTenant -ServerInstance $ServerInstance
foreach ($tenant in $tenants) {
    Write-Host Tenant: $($tenant.id)
    $installedApps = Get-NAVAppInfo -ServerInstance $ServerInstance -Tenant $tenant.Id -Publisher Microsoft -TenantSpecificProperties | Where-Object -Property IsInstalled -EQ true
    foreach ($installedApp in $installedApps) {        
        Write-Host Looking for a newer version of app $($installedApp.Name)
        $availableApp = Get-NAVAppInfo -ServerInstance $ServerInstance -Id $installedApp.AppId | Where-Object -Property Version -gt $installedApp.Version | Sort-Object -Property Version | Select-Object -Last 1
        if ($availableApp) {
            Write-Host Upgrading to version $availableApp.Version
            Sync-NAVApp -ServerInstance $ServerInstance -Tenant $tenant.id -AppName $installedApp.Name -Version $availableApp.Version -ErrorAction SilentlyContinue
            Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Tenant $tenant.id -AppName $installedApp.Name -Version $availableApp.Version -Language da-DK -ErrorAction SilentlyContinue
        }
    }
}

$tenants = Get-NAVTenant -ServerInstance $ServerInstance
foreach ($tenant in $tenants) {
    Write-Host Tenant: $($tenant.id)
    $installedApps = Get-NAVAppInfo -ServerInstance $ServerInstance -Tenant $tenant.Id -Publisher Microsoft -TenantSpecificProperties | Where-Object -Property IsInstalled -EQ true
    foreach ($installedApp in $installedApps) {        
        Write-Host Looking for a newer version of app $($installedApp.Name)
        $availableApp = Get-NAVAppInfo -ServerInstance $ServerInstance -Id $installedApp.AppId | Where-Object -Property Version -gt $installedApp.Version | Sort-Object -Property Version | Select-Object -Last 1
        if ($availableApp) {
            Write-Host Upgrading to version $availableApp.Version
            Sync-NAVApp -ServerInstance $ServerInstance -Tenant $tenant.id -AppName $installedApp.Name -Version $availableApp.Version
            Start-NAVAppDataUpgrade -ServerInstance $ServerInstance -Tenant $tenant.id -AppName $installedApp.Name -Version $availableApp.Version -Language da-DK
        }
    }
}

$installedApps = @()

$tenants = Get-NAVTenant -ServerInstance $ServerInstance 
foreach ($tenant in $tenants) {
    Write-Host Tenant: $($tenant.id)
    $installedApps += Get-NAVAppInfo -ServerInstance $ServerInstance -Tenant $tenant.Id | Where-Object -Property Publisher -EQ Microsoft
}

$publishedApps = (Get-NAVAppInfo -ServerInstance $ServerInstance | Where-Object -Property Publisher -EQ Microsoft | Sort-Object -Property Name)
foreach ($publishedApp in $publishedApps) {        
    if ($installedApps | Where-Object -Property appId -EQ $publishedApp.appId | Where-Object -Property Version -EQ $publishedApp.Version) {
        Write-Host App $($publishedApp.Name) version $($publishedApp.Version) is in use
    } elseif (($publishedApps | Where-Object -Property appId -EQ $publishedApp.appId).Count -eq 1) {
        Write-Host App $($publishedApp.Name) version $($publishedApp.Version) is the latest version
    } else {
        Write-Host Unpublishing App $($publishedApp.Name) version $($publishedApp.Version)
        Unpublish-NAVApp -ServerInstance $ServerInstance -Name $publishedApp.Name -Publisher $publishedApp.Publisher -Version $publishedApp.Version
    }
}