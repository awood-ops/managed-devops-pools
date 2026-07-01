// Test bicep for the managed-devops-pools defaults scenario.
// Creates a dedicated resource group, then deploys the module with minimum concurrency.
// namePrefix derives all resource names — keeps parallel scenario runs isolated.

targetScope = 'subscription'

@description('Short prefix for all test resources')
param namePrefix string

@description('Azure region for test resources')
param location string = 'uksouth'

@description('Azure DevOps organisation URL')
param organizationUrl string

var rgName   = 'dep-${namePrefix}-mdp'
var dcName   = '${namePrefix}-dc'
var projName = '${namePrefix}-proj'
var poolName = '${namePrefix}-pool'

resource testRg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: rgName
  location: location
}

module mdp '../../../bicep/main.bicep' = {
  name: 'mdp-test-defaults'
  scope: testRg
  params: {
    devCenterName:        dcName
    devCenterProjectName: projName
    poolName:             poolName
    organizationUrl:      organizationUrl
    maximumConcurrency:   1
    vmSize:               'Standard_D2s_v5'
    osType:               'Windows'
    agentLifecycle:       'Stateless'
    environment:          'test'
    tags: {
      environment: 'test'
      managedBy:   'bicep'
      repo:        'managed-devops-pools'
    }
  }
}

output resourceGroupName    string = testRg.name
output moduleNamePrefix     string = namePrefix
output devCenterName        string = dcName
output devCenterProjectName string = projName
output poolName             string = poolName
