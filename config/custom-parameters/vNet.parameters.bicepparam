using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/vNet.bicep'

param location = 'uksouth'

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param vNetName = 'vnet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param subnetName = 'snet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param vNetAddressSpace = '10.0.0.0/24'

param dnsServers = []

param parTags = {
  Environment: parEnvironment
  ServiceName: parProjectCode
  CompanyCode: parCompanyCode
  Version: parVersion
}

param parResourceLockConfig = {
  kind: 'CanNotDelete'
  notes: 'This lock was created by the Bicep vNet Module'
}
