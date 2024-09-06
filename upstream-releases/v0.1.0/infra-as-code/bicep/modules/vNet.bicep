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

@sys.description('Environment.')
param parEnvironment string

@sys.description('Company Code')
param parCompanyCode string

@sys.description('Project Code')
param parProjectCode string

@sys.description('Version')
param parVersion string

@description('The name of the vnet.')
param vNetName string

@description('The name of the subnet.')
param subnetName string

@description('The vNet address space.')
param vNetAddressSpace string

@description('The DNS servers.')
param dnsServers array 

@description('The tags to be associated with the VMSS.')
param parTags object = {
  bicep: 'true'
}

@description('''Resource Lock Configuration for vNet.

- `kind` - The lock settings of the service which can be CanNotDelete, ReadOnly, or None.
- `notes` - Notes about this lock.

''')
param parResourceLockConfig lockType = {
  kind: 'None'
  notes: 'This lock was created by the vNet Module.'
}

resource resNSG 'Microsoft.Network/networkSecurityGroups@2023-09-01' existing = {
  name: 'nsg-${subnetName}'
  }


resource resVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vNetName
  location: location
  tags: parTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressSpace
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: vNetAddressSpace
          networkSecurityGroup: {
            id: resNSG.id
          }
        }
      }
    ]
    dhcpOptions: dnsServers != null ? {
      dnsServers: dnsServers
    } : null
  }
}

  resource resvNetLock 'Microsoft.Authorization/locks@2020-05-01' = if (!empty(parResourceLockConfig ?? {}) && parResourceLockConfig.kind != 'None') {
    scope: resVirtualNetwork
    name: parResourceLockConfig.?name ?? '${resVirtualNetwork.name}-lock'
    properties: {
      level: parResourceLockConfig.kind
      notes: parResourceLockConfig.?notes ?? ''
    }
  }
