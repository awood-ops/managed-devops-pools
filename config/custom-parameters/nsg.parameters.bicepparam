using '../../upstream-releases/v0.1.0/infra-as-code/bicep/modules/nsg.bicep'

param parNSGName = 'nsg-snet-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'
param parLocation = 'uksouth'

param parEnvironment = ''
param parCompanyCode = ''
param parProjectCode = ''
param parVersion = ''

param parSubscriptionId = ''
param parResourceGroupName = ''
param parVMSSAsgName = 'asg-vmss-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'
param parKVAsgName = 'asg-kv-${parCompanyCode}-${parEnvironment}-${parProjectCode}-01'
param parStorageAsgName = 'asg-st${parCompanyCode}${parEnvironment}${parProjectCode}01'

param parTags = {
  Environment: parEnvironment
  ServiceName: parProjectCode
  CompanyCode: parCompanyCode
  Version: parVersion
}

param parResourceLockConfig = {
  kind: 'CanNotDelete'
  notes: 'This lock was created by the NSG Module.'
}

param securityRules = [
  {
    name: 'Deny-Inbound-Any-Implicit-All'
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
  {
    name: 'Deny-Outbound-Any-Implicit-All'
    priority: 4096
    direction: 'Outbound'
    access: 'Deny'
    protocol: '*'
    sourceAddressPrefix: '*'
    sourcePortRange: '*'
    destinationAddressPrefix: '*'
    destinationPortRange: '*'
  }
  /*{
    name: 'Allow-Outbound-VMSS-Keyvault-HTTPS-Public'
    priority: 100
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'AzureKeyVault.UKSouth'
    destinationPortRange: '443'
  }*/
  {
    name: 'Allow-Outbound-VMSS-Keyvault-HTTPS-Private'
    priority: 101
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationApplicationSecurityGroups: parKVAsgName
    destinationPortRange: '443'
  }
  /*{
    name: 'Allow-Outbound-VMSS-AzureStorage-HTTPS-Public'
    priority: 110
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'Storage.UKSouth'
    destinationPortRange: '443'
  }*/
  {
    name: 'Allow-Outbound-VMSS-AzureStorage-HTTPS-Private'
    priority: 111
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationApplicationSecurityGroups: parStorageAsgName
    destinationPortRange: '443'
  }
  /*{
    name: 'Allow-Outbound-VMSS-APP-HTTP-Public'
    priority: 120
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'AppService.UKSouth'
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-APP-HTTPS-Private'
    priority: 121
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with App Service Private IP
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-APPSCM-HTTPS-Private'
    priority: 122
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with App Service SCM Private IP
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-SQL-1433-Public'
    priority: 130
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'Sql.UKSouth'
    destinationPortRange: '1433'
  }
  {
    name: 'Allow-Outbound-VMSS-SQL-1433-Private'
    priority: 131
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with SQL Server Private IP
    destinationPortRange: '1433'
  }
  {
    name: 'Allow-Outbound-VMSS-DataFactory-HTTPS-Public'
    priority: 140
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'DataFactory.UKSouth'
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-DataFactory-HTTPS-Private'
    priority: 141
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with Data Factory Private IP
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-Databricks-HTTPS-Public'
    priority: 150
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'AzureDatabricks'
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-Databricks-HTTPS-Private'
    priority: 151
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with Databricks Private IP
    destinationPortRange: '443'
  }
  {
    name: 'Allow-Outbound-VMSS-DC-DNS-Private'
    priority: 900
    direction: 'Outbound'
    access: 'Allow'
    protocol: '*'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with DC Private IP
    destinationPortRange: '53'
  }
  {
    name: 'Allow-Outbound-VMSS-AzureFirewall-DNS-Private'
    priority: 901
    direction: 'Outbound'
    access: 'Allow'
    protocol: '*'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: '*' // Replace with Azure Firewall Private IP
    destinationPortRange: '53'
  }*/
  {
    name: 'Allow-Outbound-VMSS-Internet-HTTPS'
    priority: 1000
    direction: 'Outbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourceApplicationSecurityGroups: parVMSSAsgName
    sourcePortRange: '*'
    destinationAddressPrefix: 'Internet'
    destinationPortRange: '443'
  }
]
