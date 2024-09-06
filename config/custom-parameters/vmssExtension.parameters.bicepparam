using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/vmssExtension.bicep'

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param storageAccountName = 'st${parCompanyCode}${parEnvironment}${parProjectCode}01'
param vmssName = 'vmss-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'

