targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Optional parameters to override the default azd resource naming conventions. Update the main.parameters.json file to provide values. e.g.,:
// "resourceGroupName": {
//      "value": "myGroupName"
// }

param backendServiceName string = 'todo-back'
param frontendServiceName string = 'todo-front'
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param containerAppsEnvironmentName string = ''
param containerRegistryName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param keyVaultName string = ''
param secretStoreName string = 'secretstore'
param storageAccountName string = 'todostorage'
param blobContainerName string = 'todoitems'

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('The image name for the api service')
param apiImageName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module security 'app/security.bicep' = {
  name: 'security'
  scope: rg
  params: {
    location: location
    managedIdentityName: '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    principalId: principalId
    tags: tags
    vaultName: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
  }
}

// Shared App Env with Dapr configuration for db
module appEnv './app/app-env.bicep' = {
  name: 'app-env'
  scope: rg
  params: {
    containerAppsEnvName: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}'
    containerRegistryName: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    principalId: security.outputs.managedIdentityClientlId
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    daprEnabled: true
    storageAccountName: storageAccountName
    blobContainerName: blobContainerName
    secretStoreName: secretStoreName
    vaultName: security.outputs.keyVaultName
  }
}

// Api backend
module backend './app/api.bicep' = {
  name: 'backend'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}${backendServiceName}-${resourceToken}'
    location: location
    imageName: apiImageName
    containerAppsEnvironmentName: appEnv.outputs.environmentName
    containerRegistryName: appEnv.outputs.registryName
    serviceName: backendServiceName
    keyVaultName: security.outputs.keyVaultName
    managedIdentityName: security.outputs.managedIdentityName
  }
}

// Frontend backend
module frontend './app/api.bicep' = {
  name: 'frontend'
  scope: rg
  params: {
    name: '${abbrs.appContainerApps}${frontendServiceName}-${resourceToken}'
    location: location
    imageName: apiImageName
    containerAppsEnvironmentName: appEnv.outputs.environmentName
    containerRegistryName: appEnv.outputs.registryName
    serviceName: frontendServiceName
    keyVaultName: security.outputs.keyVaultName
    managedIdentityName: security.outputs.managedIdentityName
  }
}


// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

// App outputs
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output APPLICATIONINSIGHTS_NAME string = monitoring.outputs.applicationInsightsName
output AZURE_CONTAINER_ENVIRONMENT_NAME string = appEnv.outputs.environmentName
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = appEnv.outputs.registryLoginServer
output AZURE_CONTAINER_REGISTRY_NAME string = appEnv.outputs.registryName
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_KEY_VAULT_ENDPOINT string = security.outputs.keyVaultEndpoint
output AZURE_KEY_VAULT_NAME string = security.outputs.keyVaultName
output AZURE_MANAGED_IDENTITY_NAME string = security.outputs.managedIdentityName
output SERVICE_BACKEND_NAME string = backend.outputs.SERVICE_API_NAME
output SERVICE_FRONTEND_NAME string = frontend.outputs.SERVICE_API_NAME
