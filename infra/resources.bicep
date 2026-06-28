@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}


param azuredev7adfExists bool
param existingSlotResourceId string
param aiFoundryProjectEndpoint string

@description('Id of the user or app to assign application roles')
param principalId string

@description('Principal type of user or app')
param principalType string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

var existingSlotResourceIdSegments = split(existingSlotResourceId, '/')
resource existingSlotResource 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  scope: resourceGroup(existingSlotResourceIdSegments[2], existingSlotResourceIdSegments[4])
  name: join(map(range(0, length(split('Microsoft.CognitiveServices/accounts', '/')) - 1), i => existingSlotResourceIdSegments[8 + i * 2]), '/')
}

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}
// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: azuredev7adfIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module azuredev7adfIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'azuredev7adfidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}azuredev7adf-${resourceToken}'
    location: location
  }
}
module azuredev7adfFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'azuredev7adf-fetch-image'
  params: {
    exists: azuredev7adfExists
    name: 'azuredev-7adf'
  }
}

module azuredev7adf 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'azuredev7adf'
  params: {
    name: 'azuredev-7adf'
    ingressTargetPort: 80
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList:  [
      ]
    }
    containers: [
      {
        image: azuredev7adfFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: azuredev7adfIdentity.outputs.clientId
          }
          {
            name: 'AZURE_AI_PROJECT_ENDPOINT'
            value: aiFoundryProjectEndpoint
          }
          {
            name: 'PORT'
            value: '80'
          }
          {
            name: 'AZURE_OPENAI_SLOT_RESOURCE_ENDPOINT'
            value: existingSlotResource.properties.endpoint
          }
        ]
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [azuredev7adfIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: azuredev7adfIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'azuredev-7adf' })
  }
}

resource azuredev7adfbackendRoleAzureAIDeveloperRG 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, azuredev7adfIdentity.name, '64702f94-c441-49e6-a78b-ef80e0188fee')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '64702f94-c441-49e6-a78b-ef80e0188fee') 
    principalId: azuredev7adfIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource azuredev7adfbackendRoleCognitiveServicesUserRG 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id, resourceGroup().id, azuredev7adfIdentity.name, 'a97b65f3-24c7-4388-baec-2e87135dc908')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') 
    principalId: azuredev7adfIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_RESOURCE_AZUREDEV_7ADF_ID string = azuredev7adf.outputs.resourceId
