using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/keyVault.bicep'

param parVaultName = 'kv-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'
param parLocation = 'uksouth'

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param parSubnetName = 'snet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'
param parVNetName = 'vnet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param parTags = {
  Environment: parEnvironment
  ServiceName: parProjectCode
  CompanyCode: parCompanyCode
  Version: parVersion
}

param parResourceLockConfig = {
  kind: 'CanNotDelete'
  notes: 'This lock was created by the KeyVault Module.'
}
