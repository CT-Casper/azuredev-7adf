metadata = {
  description: 'Azure resource deployment'
}

targetScope = 'resourceGroup'

param location string = resourceGroup().location
param storageAccountName string = uniqueString(resourceGroup().id, subscription().id)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
	name: toLower('${substring(storageAccountName, 0, 22)}sa')
	location: location
	kind: 'StorageV2'
	sku: {
		name: 'Standard_LRS'
	}
	properties: {
		accessTier: 'Hot'
	}
}

output storageAccountId string = storageAccount.id

