using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/vmss.bicep'

param location = 'uksouth'

param vmSku = 'Standard_B8ms'

param instanceCount = 1

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param parSubscriptionId = ''

param nameSubfix = 'vm${parCompanyCode}${parEnvironment}'

param vmssName = 'vmss-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param vNetName = 'vnet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

param storageAccountName = 'st${parCompanyCode}${parEnvironment}${parProjectCode}01'

param osType = 'Windows'

param adminUsername = '${parCompanyCode}-${parEnvironment}-admin'

param adminPassword = az.getSecret('${parSubscriptionId}','rg-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01', 'kv-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01', '${parEnvironment}-vmss-password')

param parTags = {
  Environment: parEnvironment
  ServiceName: parProjectCode
  CompanyCode: parCompanyCode
  Version: parVersion
}

param parResourceLockConfig = {
  kind: 'CanNotDelete'
  notes: 'This lock was created by the Bicep VMSS Module'
}
