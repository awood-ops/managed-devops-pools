type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

@description('''Resource Lock Configuration for Storage Accout.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parResourceLockConfig lockType = {
  kind: 'None'
  notes: 'This lock was created by the Storage Account Module.'
}

@sys.description('Environment.')
param parEnvironment string

@sys.description('Company Code')
param parCompanyCode string

@sys.description('Project Code')
param parProjectCode string

@sys.description('Version')
param parVersion string

@description('Specifies the Azure location where the deployed resources should be created. i.e. uksouth')
param parLocation string

@description('Storage Account Name to be deployed')
param parStorageAccountName string

@description('Sets the account type of the Azure Blob')
param parStorageAccountType string

@description('Resource Tags')
param parTags object

@description('Virtual Network Name')
param parVNetName string

@description('Subnet Name')
param parSubnetName string

resource resSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  name: '${parVNetName}/${parSubnetName}'
}

resource applicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2023-11-01' existing = {
  name: 'asg-${parStorageAccountName}'
}

resource resStorageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' = {
  name: parStorageAccountName
  location: parLocation
  sku: {
    name: parStorageAccountType
  }
  kind: 'StorageV2'
  tags: parTags
  properties: {
    accessTier: 'Hot'
    defaultToOAuthAuthentication: false
    allowCrossTenantReplication: false
    isNfsV3Enabled: false
    isSftpEnabled: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    allowedCopyScope: 'PrivateLink'
    isHnsEnabled: false
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    encryption: {
      requireInfrastructureEncryption: true
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

resource resBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-04-01' = {
  name: 'default'
  parent: resStorageAccount
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    isVersioningEnabled: false
    containerDeleteRetentionPolicy: {
      days: 7
    }
    defaultServiceVersion: '2020-08-04'
    lastAccessTimeTrackingPolicy: {
      enable: false
    }
    changeFeed: {
      enabled: false
    }
  }
}

resource resBlobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-04-01' = {
  name: 'config'
  parent: resBlobService
}

resource resBlobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${resStorageAccount.name}-blob'
  tags: parTags
  location: parLocation
  properties: {
    customNetworkInterfaceName: 'nic-${resStorageAccount.name}'
    privateLinkServiceConnections: [
      {
        name: 'plsc-${resStorageAccount.name}'
        properties: {
          privateLinkServiceId: resStorageAccount.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: resSubnet.id
    }
    applicationSecurityGroups: [
      {
        id: applicationSecurityGroup.id
      }
    ]
  }
}

resource resStorageAccountLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resStorageAccount
  name: parResourceLockConfig.?name ?? '${resStorageAccount.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

resource resBlobContainerLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resBlobContainer
  name: parResourceLockConfig.?name ?? '${resBlobContainer.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}

resource resBlobPrivateEndpointLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: resBlobPrivateEndpoint
  name: parResourceLockConfig.?name ?? '${resBlobPrivateEndpoint.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}
