type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

@sys.description('''Resource Lock Configuration for KeyVault.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parResourceLockConfig lockType = {
  kind: 'None'
  notes: 'This lock was created by the ALZ Bicep Resource Group Module.'
}

@description('Resource Tags')
param parTags object

@description('Virtual Network Name')
param parVNetName string

@description('Subnet Name')
param parSubnetName string

param parVaultName string
param parLocation string = resourceGroup().location

@sys.description('Environment.')
param parEnvironment string

@sys.description('Company Code')
param parCompanyCode string

@sys.description('Project Code')
param parProjectCode string

@sys.description('Version')
param parVersion string

resource resSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${parVNetName}/${parSubnetName}'
}

resource applicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2023-11-01' existing = {
  name: 'asg-${parVaultName}'
}

resource resVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: parVaultName
  tags: parTags
  location: parLocation
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
  }
}

resource resVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${parVaultName}-vault'
  tags: parTags
  location: parLocation
  properties: {
    customNetworkInterfaceName: 'nic-${parVaultName}'
    subnet: {
      id: resSubnet.id
    }
    applicationSecurityGroups: [
      {
        id: applicationSecurityGroup.id
      }
    ]
    privateLinkServiceConnections: [
      {
        name: 'plsc-${parVaultName}'
        properties: {
          privateLinkServiceId: resVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource resKeyVaultLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resVault
  name: parResourceLockConfig.?name ?? '${resVault.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

resource resVaultPrivateEndpointLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resVaultPrivateEndpoint
  name: parResourceLockConfig.?name ?? '${resVaultPrivateEndpoint.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}
