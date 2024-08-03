param location string = resourceGroup().location
param properties {
  name: string
  rules: {
    access: ('Allow' | 'Deny')
    description: string?
    destination: {
      addressPrefixes: string[]
      applicationSecurityGroups: {
        name: string
        resourceGroupName: string?
        subscriptionId: string?
      }[]?
      ports: string[]
    }
    direction: ('Inbound' | 'Outbound')
    name: string
    priority: int
    protocol: ('*' | 'Ah' | 'Esp' | 'Icmp' | 'Tcp' | 'Udp')
    source: {
      addressPrefixes: string[]
      applicationSecurityGroups: {
        name: string
        resourceGroupName: string?
        subscriptionId: string?
      }[]?
      ports: string[]
    }
  }[]?
}

@export()
var abbreviation = 'NSG'
var name = properties.name

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  location: location
  name: properties.name
  properties: {
    flushConnection: false
    securityRules: [for rule in (properties.?rules ?? []): {
      name: rule.name
      properties: {
        access: rule.access
        description: rule.?description
        destinationAddressPrefix: ((1 == length(rule.destination.addressPrefixes)) ? first(rule.destination.addressPrefixes) : null)
        destinationAddressPrefixes: ((1 < length(rule.destination.addressPrefixes)) ? rule.destination.addressPrefixes : null)
        destinationApplicationSecurityGroups: map((rule.destination.?applicationSecurityGroups ?? []), group => {
          id: resourceId(
            (group.?subscriptionId ?? subscription().subscriptionId),
            (group.?resourceGroupName ?? resourceGroup().name),
            'Microsoft.Network/applicationSecurityGroups',
            group.name
          )
        })
        destinationPortRange: ((1 == length(rule.destination.ports)) ? first(rule.destination.ports) : null)
        destinationPortRanges: ((1 < length(rule.destination.ports)) ? rule.destination.ports : null)
        direction: rule.direction
        priority: rule.priority
        protocol: rule.protocol
        sourceAddressPrefix: ((1 == length(rule.source.addressPrefixes)) ? first(rule.source.addressPrefixes) : null)
        sourceAddressPrefixes: ((1 < length(rule.source.addressPrefixes)) ? rule.source.addressPrefixes : null)
        sourceApplicationSecurityGroups: map((rule.source.?applicationSecurityGroups ?? []), group => {
          id: resourceId(
            (group.?subscriptionId ?? subscription().subscriptionId),
            (group.?resourceGroupName ?? resourceGroup().name),
            'Microsoft.Network/applicationSecurityGroups',
            group.name
          )
        })
        sourcePortRange: ((1 == length(rule.source.ports)) ? first(rule.source.ports) : null)
        sourcePortRanges: ((1 < length(rule.source.ports)) ? rule.source.ports : null)
      }
    }]
  }
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
