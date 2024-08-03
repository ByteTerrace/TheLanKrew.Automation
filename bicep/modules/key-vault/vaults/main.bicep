param location string = resourceGroup().location
param properties {
  keys: {
    allowedOperations: ('decrypt' | 'encrypt' | 'import' | 'release' | 'sign' | 'unwrapKey' | 'verify' | 'wrapKey')[]
    name: string
    size: int
    type: ('RSA-HSM')
  }[]?
  name: string
  networking: {
    isAllowTrustedMicrosoftServicesEnabled: bool
  }
}

var name = properties.name

resource keys 'Microsoft.KeyVault/vaults/keys@2023-07-01' = [for key in (properties.?keys ?? []): {
  name: key.name
  parent: vault
  properties: {
    attributes: {
      enabled: true
      exp: null
      exportable: false
      nbf: null
    }
    curveName: null
    keyOps: key.allowedOperations
    kty: key.type
    keySize: key.size
    rotationPolicy: {
      attributes: {
        expiryTime: 'P73D'
      }
      lifetimeActions: [
        {
          action: {
            type: 'rotate'
          }
          trigger: {
            timeAfterCreate: 'P31D'
          }
        }
        {
          action: {
            type: 'notify'
          }
          trigger: {
            timeBeforeExpiry: 'P30D'
          }
        }
      ]
    }
  }
}]
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' =  {
  location: location
  name: name
  properties: {
    accessPolicies: []
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    networkAcls: {
      bypass: (properties.networking.isAllowTrustedMicrosoftServicesEnabled ? 'AzureServices' : 'None')
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Disabled'
    sku: {
      family: 'A'
      name: 'premium'
    }
    softDeleteRetentionInDays: 90
    tenantId: subscription().tenantId
  }
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
