param location string = resourceGroup().location
param properties {
  images: {
    architecture: 'x64'
    description: string?
    generation: 'V2'
    identifier: {
      publisher: string
      offer: string
      sku: string
    }
    name: string
    roleAssignments: {
      description: string?
      principalId: string
      roleDefinitionId: string
    }[]?
  }[]?
  name: string
  roleAssignments: {
    description: string?
    principalId: string
    roleDefinitionId: string
  }[]?
}

@export()
var abbreviation = 'GAL'
var imagesRoleAssignments = flatten(map(
  (properties.?images ?? []),
  (image, imageIndex) => map(
    (image.?roleAssignments ?? []),
    (roleAssignment, roleAssignmentIndex) => {
      imageIndex: imageIndex
      roleAssignmentIndex: roleAssignmentIndex
      value: roleAssignment
    }
  )
))
var name = replace(properties.name, '-', '')

resource gallery 'Microsoft.Compute/galleries@2023-07-03' = {
  location: location
  name: name
  properties: {}
}
resource images 'Microsoft.Compute/galleries/images@2023-07-03' = [for image in (properties.?images ?? []): {
  location: location
  name: image.name
  parent: gallery
  properties: {
    architecture: image.architecture
    description: image.?description
    features: [
      {
        name: 'IsAcceleratedNetworkSupported'
        value: 'true'
      }
      {
        name: 'SecurityType'
        value: 'TrustedLaunchAndConfidentialVmSupported'
      }
    ]
    hyperVGeneration: image.generation
    identifier: image.identifier
    osState: 'Generalized'
    osType: 'Windows'
  }
}]
module roleAssignmentsForGallery '../../authorization/role-assignments/main.json' = [for (roleAssignment, index) in (properties.?roleAssignments ?? []): {
  name: '${deployment().name}-${uniqueString('rbac', string(index))}'
  params: {
    properties: {
      roleAssignments: [{
        description: roleAssignment.?description
        principalId: roleAssignment.principalId
        roleDefinitionId: roleAssignment.roleDefinitionId
      }]
      scope: gallery.id
    }
  }
}]
module roleAssignmentsForImages '../../authorization/role-assignments/main.json' = [for (roleAssignment, index) in imagesRoleAssignments: {
  name: '${deployment().name}-${uniqueString('rbac-images', string(index))}'
  params: {
    properties: {
      roleAssignments: [{
        description: roleAssignment.value.?description
        principalId: roleAssignment.value.principalId
        roleDefinitionId: roleAssignment.value.roleDefinitionId
      }]
      scope: images[roleAssignment.imageIndex].id
    }
  }
}]

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
