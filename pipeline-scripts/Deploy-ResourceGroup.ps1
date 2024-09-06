param (
  [Parameter()]
  [String]$Location = "$($env:LOCATION)",

  [Parameter()]
  [String]$SubscriptionId = "$($env:SUBSCRIPTION_ID)",

  [Parameter()]
  [String]$Environment = "$($env:ENVIRONMENT)",

  [Parameter()]
  [String]$CompanyCode = "$($env:COMPANY_CODE)",

  [Parameter()]
  [String]$ProjectCode = "$($env:PROJECT_CODE)",

  [Parameter()]
  [String]$Version = "$($env:VERSION)",

  [Parameter()]
  [String]$TemplateFile = "upstream-releases\$($version)\infra-as-code\bicep\modules\resourceGroup.bicep",

  [Parameter()]
  [String]$TemplateParameterFile = "config\custom-parameters\resourceGroup.parameters.bicepparam",

  [Parameter()]
  [Boolean]$WhatIfEnabled = [System.Convert]::ToBoolean($($env:IS_PULL_REQUEST))
)

# Parameters necessary for deployment
$inputObject = @{
  DeploymentName        = 'VMSSRGDeploy-{0}' -f ( -join (Get-Date -Format 'yyyyMMddTHHMMssffffZ')[0..63])
  Location              = $Location
  TemplateFile          = $TemplateFile
  TemplateParameterFile = $TemplateParameterFile
  parEnvironment        = $Environment
  parCompanyCode        = $CompanyCode
  parProjectCode        = $ProjectCode
  parVersion            = $Version
  WhatIf                = $WhatIfEnabled
  Verbose               = $true
}

Select-AzSubscription -SubscriptionId $SubscriptionId

New-AzSubscriptionDeployment @inputObject
