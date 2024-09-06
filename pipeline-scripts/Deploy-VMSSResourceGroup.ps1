param (
  [Parameter()]
  [String]$Location = "$($env:LOCATION)",

  [Parameter()]
  [String]$SubscriptionId = "$($env:SUBSCRIPTION_ID)",

  [Parameter()]
  [String]$Environment = "$($env:ENVIRONMENT)",

  [Parameter()]
  [String]$TemplateFile = "config\custom-modules\resourceGroup.bicep",

  [Parameter()]
  [String]$TemplateParameterFile = "config\custom-parameters\resourceGroup.parameters.$($Environment).json",

  [Parameter()]
  [Boolean]$WhatIfEnabled = [System.Convert]::ToBoolean($($env:IS_PULL_REQUEST))
)

# Parameters necessary for deployment
$inputObject = @{
  DeploymentName        = 'VMSSRGDeploy-{0}' -f ( -join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
  Location              = $Location
  TemplateFile          = $TemplateFile
  TemplateParameterFile = $TemplateParameterFile
  WhatIf                = $WhatIfEnabled
  Verbose               = $true
}

Select-AzSubscription -SubscriptionId $SubscriptionId

New-AzSubscriptionDeployment @inputObject
