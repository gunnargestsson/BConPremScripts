Import-Module AzureRM
Import-Module AzureAD
Import-Module MSOnline

$AzureCredential = Get-Credential -Message "Remote Login to Azure Dns" -ErrorAction Stop    
$Login = Login-AzureRmAccount -Credential $AzureCredential
$Subscription = Select-AzureRmSubscription -SubscriptionName "Visual Studio Ultimate with MSDN" -ErrorAction Stop
$MsolService = Connect-MsolService -Credential $AzureCredential 
$AzureAD = Connect-AzureAD -Credential $AzureCredential 
$ResourceGroup = Get-AzureRmResourceGroup -Name WestEuropeStorage
