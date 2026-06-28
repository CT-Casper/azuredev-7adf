targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@metadata({azd: {
  type: 'location'
  usageName: [
    'OpenAI.Standard.gpt4.1,1'
  ]}
})
param aiDeploymentsLocation string
param azuredev7adfExists bool
param existingSlotResourceId string

@description('Id of the user or app to assign application roles')
param principalId string

@description('Principal type of user or app')
param principalType string

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  scope: rg
  name: 'resources'
  params: {
    location: location
    tags: tags
    principalId: principalId
    principalType: principalType
    azuredev7adfExists: azuredev7adfExists
    existingSlotResourceId: existingSlotResourceId
    aiFoundryProjectEndpoint: aiModelsDeploy.outputs.ENDPOINT
  }
}

module aiModelsDeploy 'ai-project.bicep' = {
  scope: rg
  name: 'ai-project'
  params: {
    tags: tags
    location: aiDeploymentsLocation
    envName: environmentName
    principalId: principalId
    principalType: principalType
    deployments: [
      {
        name: 'gpt41Deployment'
        model: {
          name: 'gpt-4.1'
          format: 'OpenAI'
          version: '2025-04-14'
        }
        sku: {
          name: 'Standard'
          capacity: 1
        }
      }
    ]
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output AZURE_RESOURCE_AZUREDEV_7ADF_ID string = resources.outputs.AZURE_RESOURCE_AZUREDEV_7ADF_ID
output AZURE_AI_PROJECT_ENDPOINT string = aiModelsDeploy.outputs.ENDPOINT
output AZURE_RESOURCE_AI_PROJECT_ID string = aiModelsDeploy.outputs.projectId
