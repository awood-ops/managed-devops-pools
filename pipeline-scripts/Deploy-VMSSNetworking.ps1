param (
  [Parameter()]
  [String]$SubscriptionId = "$($env:SUBSCRIPTION_ID)",

  [Parameter()]
  [String]$ResourceGroupName = "$($env:PROD_RESOURCE_GROUP_NAME)",

  [Parameter()]
  [String]$Environment = "$($env:ENVIRONMENT)",

  [Parameter()]
  [String]$TemplateFile = "config\custom-modules\vNet.bicep",

  [Parameter()]
  [String]$TemplateParameterFile = "config\custom-parameters\vNet.parameters.$($Environment).json",

  [Parameter()]
  [Boolean]$WhatIfEnabled = [System.Convert]::ToBoolean($($env:IS_PULL_REQUEST))
)

# Parameters necessary for deployment
$inputObject = @{
    DeploymentName        = 'VMSSNetworkingDeploy-{0}' -f ( -join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
    TemplateFile          = $TemplateFile
    ResourceGroupName     = $ResourceGroupName
    TemplateParameterFile = $TemplateParameterFile
    WhatIf                = $WhatIfEnabled
    Verbose               = $true
  }

Select-AzSubscription -SubscriptionId $SubscriptionId

New-AzResourceGroupDeployment @inputObject