param location string = resourceGroup().location
param properties {
  addressPrefixes: string[]
  name: string
  roleAssignments: {
    description: string?
    principalId: string
    roleDefinitionId: string
  }[]?
}

@export()
var abbreviation = 'VNET'
var name = properties.name

module roleAssignments '../../authorization/role-assignments/main.json' = [for (roleAssignment, index) in (properties.?roleAssignments ?? []): {
  name: '${deployment().name}-${uniqueString('rbac', string(index))}'
  params: {
    properties: {
      roleAssignments: [{
        description: roleAssignment.?description
        principalId: roleAssignment.principalId
        roleDefinitionId: roleAssignment.roleDefinitionId
      }]
      scope: virtualNetwork.id
    }
  }
}]
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  location: location
  name: properties.name
  properties: {
    addressSpace: {
      addressPrefixes: properties.addressPrefixes
    }
    enableDdosProtection: false
    encryption: {
      enabled: true
      enforcement: 'AllowUnencrypted'
    }
  }
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
