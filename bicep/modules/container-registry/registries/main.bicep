param location string = resourceGroup().location
param properties {
  name: string
  sku: {
    name: ('Basic' | 'Premium' | 'Standard')
  }
}

var name = properties.name

resource registry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  location: location
  name: name
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
    networkRuleBypassOptions: 'AzureServices'
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: 'Disabled'
  }
  sku: properties.sku
}
