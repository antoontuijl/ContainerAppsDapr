param containerAppsEnvName string
param containerRegistryName string
param secretStoreName string
param vaultName string
param location string
param logAnalyticsWorkspaceName string
param principalId string
param applicationInsightsName string
param daprEnabled bool
param storageAccountName string
param blobContainerName string

// Container apps host (including container registry)
module containerApps '../core/host/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    name: 'app'
    containerAppsEnvironmentName: containerAppsEnvName
    containerRegistryName: containerRegistryName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    daprEnabled: daprEnabled
  }
}

// Get App Env resource instance to parent Dapr component config under it
resource caEnvironment  'Microsoft.App/managedEnvironments@2022-10-01' existing = {
  name: containerAppsEnvName
}

resource daprComponentSecretStore 'Microsoft.App/managedEnvironments/daprComponents@2022-10-01' = {
  parent: caEnvironment
  name: secretStoreName
  properties: {
    componentType: 'secretstores.azure.keyvault'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5s'
    metadata: [
      {
        name: 'vaultName'
        value: vaultName
      }
      {
        name: 'azureClientId'
        value: principalId
      }
    ]
    scopes: ['batch']
  }
  dependsOn: [
    containerApps
  ]
}

// Dapr state store component 
resource daprComponent 'Microsoft.App/managedEnvironments/daprComponents@2022-03-01' = {
  name: 'statestore'
  parent: caEnvironment
  properties: {
    componentType: 'state.azure.blobstorage'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '5s'
    metadata: [
      {
        name: 'accountName'
        value: storageAccountName
      }
      {
        name: 'containerName'
        value: blobContainerName
      }
      {
        name: 'azureClientId'
        value: principalId
      }
    ]
    scopes: [
      'todo-back'
      'todo-front'
    ]
  }
}

output environmentName string = containerApps.outputs.environmentName
output registryLoginServer string = containerApps.outputs.registryLoginServer
output registryName string = containerApps.outputs.registryName
