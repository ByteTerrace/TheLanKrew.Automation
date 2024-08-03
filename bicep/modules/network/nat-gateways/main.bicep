param location string = resourceGroup().location
param properties {
  publicIpPrefixes: {
    name: string
    resourceGroupName: string?
    subscriptionId: string?
  }[]
  name: string
}

var name = properties.name

resource nateGateway 'Microsoft.Network/natGateways@2024-01-01' = {
  location: location
  name: properties.name
  properties: {
    publicIpPrefixes: [for prefix in properties.publicIpPrefixes: {
      id: resourceId(
        (prefix.?subscriptionId ?? subscription().subscriptionId),
        (prefix.?resourceGroupName ?? resourceGroup().name),
        'Microsoft.Network/publicIPPrefixes',
        prefix.name
      )
    }]
  }
  sku: {
    name: 'Standard'
  }
  zones: []
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
