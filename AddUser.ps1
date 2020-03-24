Import-Module 'C:\Program Files\Microsoft Dynamics 365 Business Central\140\Service\NavAdminTool.ps1'
$ServiceInstance = 'BC'

$Users = @()
$Users += @{UserName=$env:USERDOMAIN + '\' + $env:USERNAME;FullName="Gunnar Þór Gestsson";Email="gunnar@dynamics.is"}

function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
 
function Scramble-String([string]$inputString){     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}
 
$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 5 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 5 -characters '1234567890'
$password += Get-RandomCharacters -length 2 -characters '!"§$%&/()=?}][{@#*+'
  
$Password  = Scramble-String $Password
Write-Host "New password: $Password"
$Password = ConvertTo-SecureString -String $Password -AsPlainText -Force

foreach ($Tenant in (Get-NAVTenant -ServerInstance $ServiceInstance)) {
    foreach ($User in $Users) {
        Write-Host "Adding user to $($Tenant.Id)"
        $ExistingUser = Get-NAVServerUser -ServerInstance $ServiceInstance -Tenant $Tenant.Id | Where-Object -Property UserName -EQ $User.Username
        if ($ExistingUser) {
            Set-NAVServerUser -ServerInstance $ServiceInstance -Tenant $Tenant.Id -UserName $User.UserName -AuthenticationEmail $User.Email -LanguageId 1039 -Force -Password $Password -ChangePasswordAtNextLogOn -FullName "Gunnar Þór Gestsson"
        } else {
            New-NAVServerUser -ServerInstance $ServiceInstance -Tenant $Tenant.Id -UserName $User.UserName -FullName $User.FullName -AuthenticationEmail $User.Email -LanguageId 1039 -Force
            New-NAVServerUserPermissionSet -ServerInstance $ServiceInstance -Tenant $Tenant.Id -UserName $User.UserName -Scope System -PermissionSetId "SUPER"
        }
    }
} 