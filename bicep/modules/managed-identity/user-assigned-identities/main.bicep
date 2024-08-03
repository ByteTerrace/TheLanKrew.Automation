param location string = resourceGroup().location
param properties {
  federatedIdentityCredentials: {
    audiences: string[]
    issuer: string
    subject: string
  }[]?
  name: string
  roleAssignments: {
    description: string?
    principalId: string?
    roleDefinitionId: string
  }[]?
}

@export()
var abbreviation = 'ID'
var name = properties.name

resource federatedIdentityCredentials 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = [for credential in (properties.?federatedIdentityCredentials ?? []): {
  name: credential.name
  parent: userAssignedIdentity
  properties: {
    audiences: credential.audiences
    issuer: credential.issuer
    subject: credential.subject
  }
}]
module roleAssignments '../../authorization/role-assignments/main.json' = [for (roleAssignment, index) in (properties.?roleAssignments ?? []): {
  name: '${deployment().name}-${uniqueString('rbac', string(index))}'
  params: {
    properties: {
      roleAssignments: [{
        description: roleAssignment.?description
        principalId: (roleAssignment.?principalId ?? userAssignedIdentity.properties.principalId)
        roleDefinitionId: roleAssignment.roleDefinitionId
      }]
      scope: userAssignedIdentity.id
    }
  }
}]
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  location: location
  name: properties.name
}

output properties object = {
  clientId: userAssignedIdentity.properties.clientId
  name: name
  principalId: userAssignedIdentity.properties.principalId
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
