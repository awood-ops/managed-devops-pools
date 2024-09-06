param (
  [Parameter()]
  [String]$SubscriptionId = "$($env:SUBSCRIPTION_ID)",

  [Parameter()]
  [String]$ResourceGroupName = "$($env:RESOURCE_GROUP_NAME)",

  [Parameter()]
  [String]$Environment = "$($env:ENVIRONMENT)",

  [Parameter()]
  [String]$CompanyCode = "$($env:COMPANY_CODE)",

  [Parameter()]
  [String]$ProjectCode = "$($env:PROJECT_CODE)",

  [Parameter()]
  [String]$Version = "$($env:VERSION)",

  [Parameter()]
  [String]$TemplateFile = "upstream-releases\$($version)\infra-as-code\bicep\modules\storageAccount.bicep",

  [Parameter()]
  [String]$TemplateParameterFile = "config\custom-parameters\storageAccount.parameters.bicepparam",

  [Parameter()]
  [Boolean]$WhatIfEnabled = [System.Convert]::ToBoolean($($env:IS_PULL_REQUEST))
)

# Parameters necessary for deployment
$inputObject = @{
    DeploymentName        = 'StorageAccountDeploy-{0}' -f ( -join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
    TemplateFile          = $TemplateFile
    ResourceGroupName     = $ResourceGroupName
    TemplateParameterFile = $TemplateParameterFile
    parEnvironment        = $Environment
    parCompanyCode        = $CompanyCode
    parProjectCode        = $ProjectCode
    parVersion            = $Version
    WhatIf                = $WhatIfEnabled
    Verbose               = $true
  }

Select-AzSubscription -SubscriptionId $SubscriptionId

New-AzResourceGroupDeployment @inputObject