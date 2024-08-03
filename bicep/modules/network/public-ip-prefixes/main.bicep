param location string = resourceGroup().location
param properties {
  length: int
  name: string
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  version: ('IPv4' | 'IPv6')
}

@export()
var abbreviation = 'IPPRE'
var name = properties.name

resource publicIpPrefix 'Microsoft.Network/publicIPPrefixes@2024-01-01' = {
  location: location
  name: properties.name
  properties: {
    prefixLength: properties.length
    publicIPAddressVersion: properties.version
  }
  sku: properties.sku
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
