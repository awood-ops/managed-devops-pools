type lockType = {
  @description('Optional. Specify the name of lock.')
  name: string?

  @description('Optional. The lock settings of the service.')
  kind: ('CanNotDelete' | 'ReadOnly' | 'None')

  @description('Optional. Notes about this lock.')
  notes: string?
}

@description('Specifies the location for all resources.')
@allowed([
  'uksouth'
  'ukwest'
])
param location string

@description('The SKU of the VM.')
param vmSku string

@description('The number of VM instances.')
param instanceCount int

@description('The name of the VMSS.')
param vmssName string

//must be no longer than 9 characters
@description('The prefix for the VMSS name.')
@maxLength(9)
param nameSubfix string

@description('The name of the vnet.')
param vNetName string

@description('The operating system type.')
@allowed([
  'Windows'
  'Ubuntu'
])
param osType string

@description('The admin username for the VM.')
param adminUsername string

@secure()
@description('The admin password for the VM.')
param adminPassword string

@description('The tags to be associated with the VMSS.')
param parTags object = {
  bicep: 'true'
}

@description('''Resource Lock Configuration for VMSS.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parResourceLockConfig lockType = {
  kind: 'None'
  notes: 'This lock was created by the VMSS Module.'
}

@description('Storage Account Name')
param storageAccountName string

var buildScript = 'https://${storageAccountName}.blob.${environment().suffixes.storage}/config/build.ps1'

var osProfile = {
  computerNamePrefix: nameSubfix
  adminUsername: adminUsername
  adminPassword: adminPassword
  windowsConfiguration: osType == 'Windows' ? {
    enableAutomaticUpdates: true
  } : null
  linuxConfiguration: osType != 'Windows' ? {
    disablePasswordAuthentication: false
  } : null
}

var imageReference = {
  publisher: osType == 'Windows' ? 'MicrosoftWindowsServer' : 'Canonical'
  offer: osType == 'Windows' ? 'WindowsServer' : 'UbuntuServer'
  sku: osType == 'Windows' ? '2022-datacenter-smalldisk' : '18_04-LTS-GEN2'
  version: 'latest'
}


var osDiskConfig = {
  caching: 'ReadOnly'
  managedDisk: {
    storageAccountType: 'Standard_LRS'
  }
  createOption: 'FromImage'
  diffDiskSettings: {
    option: 'Local'
  }
  diskSizeGB: 30
}

var storageProfile = {
  imageReference: imageReference
  osDisk: osDiskConfig
}

var securityProfile = {
  encryptionAtHost: true
}

resource resVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01'existing = {
  name: vNetName
}

resource resStorageAccount 'Microsoft.Storage/storageAccounts@2023-04-01' existing = {
  name: storageAccountName
}


resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2023-09-01' = {
  name: vmssName
  location: location
  tags: parTags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Automatic'
    }
    singlePlacementGroup: false
    virtualMachineProfile: {
      osProfile: osProfile
      storageProfile: storageProfile
      securityProfile: securityProfile
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: resVirtualNetwork.properties.subnets[0].id
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource StorageBlobDataReaderResource 'Microsoft.Authorization/roleDefinitions@2015-07-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}

resource roleassignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vmssName)
  scope: resStorageAccount
  properties: {
    roleDefinitionId: StorageBlobDataReaderResource.id
    principalId: vmss.identity.principalId
  }
}

resource extension 'Microsoft.Compute/virtualMachineScaleSets/extensions@2024-03-01' = {
  name: 'customScript'
  parent: vmss
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        buildScript
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File build.ps1'
      managedIdentity: {}
    }
  }
  dependsOn: [
    roleassignment
  ]
}

resource resVMSSLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
  scope: vmss
  name: parResourceLockConfig.?name ?? '${vmss.name}-lock'
  properties: {
    level: parResourceLockConfig.kind
    notes: parResourceLockConfig.?notes ?? ''
  }
}
