using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/resourceGroup.bicep'

param parLocation = 'uksouth'

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param parResourceGroupName = 'rg-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param parTags = {
  Environment: parEnvironment
  ServiceName: parProjectCode
  CompanyCode: parCompanyCode
  Version: parVersion
}

param parResourceLockConfig = {
  kind: 'CanNotDelete'
  notes: 'This lock was created by the Bicep resourceGroup Module'
}
