param
(
    [Parameter(Mandatory = $false)]
    [string]$paramsFile = "params.json"
)


# Import the functions
. .\config\custom-modules\Authentication.ps1
. .\config\custom-modules\Service-Connection.ps1

# Read the parameters from the JSON file
$params = Get-Content $paramsFile -Raw | ConvertFrom-Json

# Loop through the parameters and create a service principal for each set of parameters
foreach ($param in $params) {
    # Extract the parameters from the object
    $companyId = $param.companyId
    $environment = $param.environment
    $app = $param.app
    $instance = $param.instance
    $OrgName = $param.OrgName
    $ProjectName = $param.ProjectName
    

# Construct the Subscription Name
$subscriptionName = "sub-$companyId-$environment-$app-$instance"

# Construct the service principal name
$spName = "sp-$subscriptionName-devops"

# Get Subscription ID, if subscription doesn't exist, exit with error
$subscriptionId = (Get-AzSubscription -SubscriptionName $subscriptionName -ErrorAction SilentlyContinue).Id
if (-not $subscriptionId) {
    Write-Error "Subscription '$subscriptionName' not found."
    return
}

# Login to Azure
#Write-Output "Logging in to Azure..."
#Connect-AzAccount

# Set the Subscription Context
Write-Output "Setting subscription context to '$subscriptionId'..."
Set-AzContext -SubscriptionId $subscriptionId

# Check if the service principal already exists, if so continue to the next set of parameters
$existingSp = Get-AzADServicePrincipal -DisplayName $spName -ErrorAction SilentlyContinue
if ($existingSp) {
    Write-Warning "Service principal '$spName' already exists. Skipping creation..."
    return
}

# Create the service principal with no secret
Write-Output "Creating service principal '$spName'..."
$sp = New-AzADServicePrincipal -DisplayName $spName

#Remove the secret from the service principal
Get-AzADApplication -DisplayName $spName | Remove-AzADAppCredential

# Assign the "Contributor" role to the service principal for the subscription if $instance equals "01"
Write-Output "Assigning 'Owner' role to service principal '$spName' for subscription '$subscriptionId'..."
New-AzRoleAssignment -ObjectId $sp.Id -RoleDefinitionName "Owner" -Scope "/subscriptions/$subscriptionId"

$token = Get-AzDevOpsAccessToken

# Create the service connection in Azure DevOps
$serviceConnectionId = (New-AzDevOpsAzureServiceConnection -OrgName $OrgName -ProjectName $ProjectName -Name "conn-$spName" -SubscriptionId $subscriptionId -SubscriptionName $subscriptionName -ServicePrincipalClientId $sp.AppId -ServicePrincipalTenantId $sp.AppOwnerOrganizationId -AccessToken $token).id

# Get the service connection ID
$Issuer = (Get-AzDevOpsAzureServiceConnection -OrgName $OrgName -ProjectName $ProjectName -ServiceConnectionId $ServiceConnectionId -AccessToken $token).authorization.parameters.workloadIdentityFederationIssuer
$subjectIdentifier = "sc://$OrgName/$ProjectName/conn-$spName"

# Get Application Object ID
$appObjectId = Get-AzADApplication -DisplayName $spName | Select-Object -Property @{Name="ApplicationObjectId";Expression={$_.Id}}

# Add Federated Credential to the App Registration
New-AzADAppFederatedCredential -ApplicationObjectId $appObjectId.ApplicationObjectId -Issuer $Issuer -Subject $subjectIdentifier -Audience "api://AzureADTokenExchange" -Name "AzureDevOps"
}