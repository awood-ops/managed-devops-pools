type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

@sys.description('Environment.')
param parEnvironment string

@sys.description('Company Code')
param parCompanyCode string

@sys.description('Project Code')
param parProjectCode string

@sys.description('Version')
param parVersion string

@description('Existing Network Security Group Name')
param parNSGName string

@description('Location')
param parLocation string

@description('Subscription ID')
param parSubscriptionId string

@description('Resource Group Name')
param parResourceGroupName string

@description('Tags')
param parTags object

@description('VMSS ASG Name')
param parVMSSAsgName string

@description('Storage ASG Name')
param parStorageAsgName string

@description('KV Asg Name')
param parKVAsgName string

@description('NSG Security Rules')
param securityRules array

@description('''Resource Lock Configuration for asg/nsg.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parResourceLockConfig lockType = {
  kind: 'None'
  notes: 'This lock was created by the vNet Module.'
}

var securityRuleArray = [for (securityRule, i) in securityRules: {
  name: securityRule.name
  properties: {
  access: securityRule.access
  description: contains(securityRule, 'description') ? securityRule.description : ''
  destinationAddressPrefix: contains(securityRule, 'destinationAddressPrefix') ? securityRule.destinationAddressPrefix : ''
  destinationAddressPrefixes: contains(securityRule, 'destinationAddressPrefixes') ? securityRule.destinationAddressPrefixes : []
  destinationApplicationSecurityGroups: contains(securityRule, 'destinationApplicationSecurityGroups') ? [{ id: resourceId('Microsoft.Network/applicationSecurityGroups', securityRule.destinationApplicationSecurityGroups) }] : []
  destinationPortRange: contains(securityRule, 'destinationPortRange') ? securityRule.destinationPortRange : ''
  destinationPortRanges: contains(securityRule, 'destinationPortRanges') ? securityRule.destinationPortRanges : []
  direction: securityRule.direction
  priority: securityRule.priority
  protocol: securityRule.protocol
  sourceAddressPrefix: contains(securityRule, 'sourceAddressPrefix') ? securityRule.sourceAddressPrefix : ''
  sourceAddressPrefixes: contains(securityRule, 'sourceAddressPrefixes') ? securityRule.sourceAddressPrefixes : []
  sourceApplicationSecurityGroups: contains(securityRule, 'sourceApplicationSecurityGroups') ? [{ id: resourceId('Microsoft.Network/applicationSecurityGroups', securityRule.sourceApplicationSecurityGroups) }] : []
  sourcePortRange: contains(securityRule, 'sourcePortRange') ? securityRule.sourcePortRange : ''
  sourcePortRanges: contains(securityRule, 'sourcePortRanges') ? securityRule.sourcePortRanges : []
  }
  }]

resource resVMSSApplicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2023-11-01' = {
  name: parVMSSAsgName
  tags: parTags
  location: parLocation
}

resource resKVApplicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2023-11-01' = {
  name: parKVAsgName
  tags: parTags
  location: parLocation
}

resource resStorageApplicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2023-11-01' = {
  name: parStorageAsgName
  tags: parTags
  location: parLocation
}

resource resNSG 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: parNSGName
  tags: parTags
  location: parLocation
  properties: {
    securityRules: securityRuleArray
  }
  dependsOn: [resVMSSApplicationSecurityGroup, resStorageApplicationSecurityGroup, resKVApplicationSecurityGroup]
}


resource resVMSSAsgLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resVMSSApplicationSecurityGroup
  name: parResourceLockConfig.?name ?? '${resVMSSApplicationSecurityGroup.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

resource resKVasgLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resKVApplicationSecurityGroup
  name: parResourceLockConfig.?name ?? '${resKVApplicationSecurityGroup.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

resource resStorageAsgLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resStorageApplicationSecurityGroup
  name: parResourceLockConfig.?name ?? '${resStorageApplicationSecurityGroup.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

resource resNsgLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resNSG
  name: parResourceLockConfig.?name ?? '${resNSG.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

