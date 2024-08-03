param properties {
  addressPrefixes: string[]
  delegations: string[]?
  isDefaultOutboundAccessEnabled: bool?
  isPrivateEndpointNetworkPolicyEnabled: bool?
  isPrivateLinkServiceNetworkPolicyEnabled: bool?
  name: string
  natGateway: {
    name: string
    resourceGroupName: string?
    subscriptionId: string?
  }?
  networkSecurityGroup: {
    name: string
    resourceGroupName: string?
    subscriptionId: string?
  }?
  roleAssignments: {
    description: string?
    principalId: string
    roleDefinitionId: string
  }[]?
  routeTable: {
    name: string
    resourceGroupName: string?
    subscriptionId: string?
  }?
  virtualNetworkName: string
}

@export()
var abbreviation = 'SNET'
var isNatGatewayAssociated = !empty(properties.?natGateway.?name)
var isNetworkSecurityGroupAssociated = !empty(properties.?networkSecurityGroup.?name)
var isRouteTableAssociated = !empty(properties.?routeTable.?name)
var name = properties.name

resource natGateway 'Microsoft.Network/natGateways@2024-01-01' existing = if (isNatGatewayAssociated) {
  name: (properties.?natGateway.?name ?? '<PLACEHOLDER>')
  scope: resourceGroup(
    (properties.?natGateway.?subscriptionId ?? subscription().subscriptionId),
    (properties.?natGateway.?resourceGroupName ?? resourceGroup().name)
  )
}
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2024-01-01' existing = if (isNetworkSecurityGroupAssociated) {
  name: (properties.?networkSecurityGroup.?name ?? '<PLACEHOLDER>')
  scope: resourceGroup(
    (properties.?networkSecurityGroup.?subscriptionId ?? subscription().subscriptionId),
    (properties.?networkSecurityGroup.?resourceGroupName ?? resourceGroup().name)
  )
}
module roleAssignments '../../authorization/role-assignments/main.json' = [for (roleAssignment, index) in (properties.?roleAssignments ?? []): {
  name: '${deployment().name}-${uniqueString('rbac', string(index))}'
  params: {
    properties: {
      roleAssignments: [{
        description: roleAssignment.?description
        principalId: roleAssignment.principalId
        roleDefinitionId: roleAssignment.roleDefinitionId
      }]
      scope: subnet.id
    }
  }
}]
resource routeTable 'Microsoft.Network/routeTables@2024-01-01' existing = if (isRouteTableAssociated) {
  name: (properties.?routeTable.?name ?? '<PLACEHOLDER>')
  scope: resourceGroup(
    (properties.?routeTable.?subscriptionId ?? subscription().subscriptionId),
    (properties.?routeTable.?resourceGroupName ?? resourceGroup().name)
  )
}
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  name: properties.name
  parent: virtualNetwork
  properties: {
    addressPrefixes: properties.addressPrefixes
    defaultOutboundAccess: (properties.?isDefaultOutboundAccessEnabled ?? false)
    delegations: [for delegation in (properties.?delegations ?? []): {
      name: delegation
      properties: {
        serviceName: delegation
      }
    }]
    natGateway: (isNatGatewayAssociated ? { id: natGateway.id } : null)
    networkSecurityGroup: (isNetworkSecurityGroupAssociated ? { id: networkSecurityGroup.id } : null)
    privateEndpointNetworkPolicies: ((properties.?isPrivateEndpointNetworkPolicyEnabled ?? true) ? 'Enabled' : 'Disabled')
    privateLinkServiceNetworkPolicies: ((properties.?isPrivateLinkServiceNetworkPolicyEnabled ?? true) ? 'Enabled' : 'Disabled')
    routeTable: (isRouteTableAssociated ? { id: routeTable.id } : null)
    serviceEndpointPolicies: []
  }
}
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: properties.virtualNetworkName
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
  virtualNetworkName: properties.virtualNetworkName
}
