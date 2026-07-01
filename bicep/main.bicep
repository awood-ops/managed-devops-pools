// Verify latest AVM versions at:
// https://azure.github.io/Azure-Verified-Modules/indexes/bicep/bicep-resource-modules/

targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Name of the Dev Center')
param devCenterName string

@description('Name of the Dev Center Project')
param devCenterProjectName string

@description('Name of the Managed DevOps Pool')
param poolName string

@description('Azure DevOps organisation URL (e.g. https://dev.azure.com/myorg)')
param organizationUrl string

@description('Azure DevOps project names this pool is available in. Empty = all projects.')
param projects array = []

@description('Maximum number of parallel agents')
@minValue(1)
@maxValue(10000)
param maximumConcurrency int = 4

@description('VM SKU for pool agents')
param vmSize string = 'Standard_D4s_v5'

@description('OS for pool agents')
@allowed(['Windows', 'Linux'])
param osType string = 'Windows'

@description('Stateless (fresh VM per job) or Stateful (reused between jobs)')
@allowed(['Stateless', 'Stateful'])
param agentLifecycle string = 'Stateless'

@description('For Stateful pools: max idle time before deallocation (ISO 8601)')
param maxAgentLifetime string = 'PT24H'

@description('Environment tag (e.g. prd, dev)')
param environment string

param tags object = {
  environment: environment
  managedBy: 'bicep'
  repo: 'DevOps-ScaleSets'
}

// ── Dev Center ───────────────────────────────────────────────────────────────

// avm/res/dev-center/dev-center is not published to MCR -- using native resource
resource devCenter 'Microsoft.DevCenter/devCenters@2024-02-01' = {
  name: devCenterName
  location: location
  tags: tags
}

module devCenterProject 'br/public:avm/res/dev-center/project:0.1.2' = {
  name: 'devCenterProject'
  params: {
    name: devCenterProjectName
    location: location
    devCenterId: devCenter.id
    tags: tags
  }
}

// ── Managed DevOps Pool ──────────────────────────────────────────────────────

module managedDevOpsPool 'br/public:avm/res/dev-ops-infrastructure/pool:0.2.0' = {
  name: 'managedDevOpsPool'
  params: {
    name: poolName
    location: location
    devCenterProjectResourceId: devCenterProject.outputs.resourceId
    maximumConcurrency: maximumConcurrency
    agentProfile: agentLifecycle == 'Stateless'
      ? { kind: 'Stateless' }
      : { kind: 'Stateful', maxAgentLifetime: maxAgentLifetime, gracePeriodTimeSpan: 'PT1H' }
    organizationProfile: {
      kind: 'AzureDevOps'
      organizations: [
        {
          url: organizationUrl
          projects: empty(projects) ? null : projects
          parallelism: maximumConcurrency
        }
      ]
    }
    fabricProfile: {
      kind: 'Managed'
      sku: { name: vmSize }
      images: [
        {
          aliases: [ osType == 'Windows' ? 'windows-2022/latest' : 'ubuntu-22.04/latest' ]
          buffer: '*'
        }
      ]
      storageProfile: { osDiskStorageAccountType: 'Standard' }
    }
    tags: tags
  }
}

// ── Outputs ──────────────────────────────────────────────────────────────────

output devCenterId string = devCenter.id
output devCenterProjectId string = devCenterProject.outputs.resourceId
output poolId string = managedDevOpsPool.outputs.resourceId
output poolName string = managedDevOpsPool.outputs.name
