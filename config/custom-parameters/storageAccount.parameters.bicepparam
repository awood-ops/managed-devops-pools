using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/storageAccount.bicep'

param parLocation = 'uksouth'

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param parStorageAccountName = 'st${parCompanyCode}${parEnvironment}${parProjectCode}01'

param parStorageAccountType = 'Standard_LRS'

param parVNetName = 'vnet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param parSubnetName = 'snet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param parTags = {
  Environment: parEnvironment
  ServiceName: parProjectCode
  CompanyCode: parCompanyCode
  Version: parVersion
}

param parResourceLockConfig = {
  kind: 'CanNotDelete'
  notes: 'This lock was created by the Bicep Storage Account Module'
}
