@description('Storage Account Name')
param storageAccountName string

@description('The name of the VMSS.')
param vmssName string

@sys.description('Environment.')
param parEnvironment string

@sys.description('Company Code')
param parCompanyCode string

@sys.description('Project Code')
param parProjectCode string

@sys.description('Version')
param parVersion string

var buildScript = 'https://${storageAccountName}.blob.${environment().suffixes.storage}/config/build.ps1'

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' existing = {
  name: vmssName
}

resource buildExtension 'Microsoft.Compute/virtualMachineScaleSets/extensions@2024-03-01' = {
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
}

resource amaagentExtension 'Microsoft.Compute/virtualMachineScaleSets/extensions@2024-03-01' = {
  name: '${vmssName}-AzureMonitorWindowsAgent'
  parent: vmss
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [
    buildExtension
  ]
}

resource antiMalwareExtension 'Microsoft.Compute/virtualMachineScaleSets/extensions@2024-03-01' = {
  name: '${vmssName}-IaaSAntimalware'
  parent: vmss
  properties: {
    publisher: 'Microsoft.Azure.Security'
    type: 'IaaSAntimalware'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      AntimalwareEnabled: true
      RealtimeProtectionEnabled: true
      ScheduledScanSettings: {
        isEnabled: true
        scanType: 'Quick'
        day: '7'
        time: '120'
      }
    }
  }
  dependsOn: [
    amaagentExtension
  ]
}
