import { createIdentityObject, } from '../../../functions/main.bicep'

param location string = resourceGroup().location
param properties {
  customerManagedEncryption: {
    keyName: string
    keyVault: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
    }
    userAssignedIdentity: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
    }
  }
  identity: {
    userAssignedIdentities: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
    }[]
  }
  kind: ('BlobStorage' | 'BlockBlobStorage' | 'FileStorage' | 'Storage' | 'StorageV2')
  name: string
  sku: {
    name: ('Premium_LRS' | 'Premium_ZRS' | 'Standard_GRS' | 'Standard_GZRS' | 'Standard_LRS' | 'Standard_RAGRS' | 'Standard_RAGZRS' | 'Standard_ZRS')
  }
}

var customerManagedEncryption = (properties.?customerManagedEncryption ?? {
  keyName: ''
  keyVault: {
    name: ''
    resourceGroupName: null
    subscriptionId: null
  }
  userAssignedIdentity: null
})
var identity = createIdentityObject(false, properties.identity.userAssignedIdentities)
var isCustomerManagedEncyptionEnabled = (!empty(customerManagedEncryption.keyVault.name) || !empty(customerManagedEncryption.keyName))
var name = toLower(replace(properties.name, '-', ''))

resource customerManagedEncyptionKeyVaultRef 'Microsoft.KeyVault/vaults@2023-07-01'  existing = if (isCustomerManagedEncyptionEnabled) {
  name: customerManagedEncryption.keyVault.name
  scope: resourceGroup(
    (customerManagedEncryption.keyVault.?subscriptionId ?? subscription().subscriptionId),
    (customerManagedEncryption.keyVault.?resourceGroupName ?? resourceGroup().name)
  )
}
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  identity: identity
  kind: properties.kind
  location: location
  name: name
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    allowCrossTenantReplication: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    dnsEndpointType: 'Standard'
    encryption: {
      identity: {
        userAssignedIdentity: resourceId(
          (customerManagedEncryption.userAssignedIdentity.?subscriptionId ?? subscription().subscriptionId),
          (customerManagedEncryption.userAssignedIdentity.?resourceGroupName ?? resourceGroup().name),
          'Microsoft.ManagedIdentity/userAssignedIdentities',
          customerManagedEncryption.userAssignedIdentity.name
        )
      }
      keySource: 'Microsoft.Keyvault'
      keyvaultproperties: {
        keyname: customerManagedEncryption.keyName
        keyvaulturi: customerManagedEncyptionKeyVaultRef.properties.vaultUri
      }
      requireInfrastructureEncryption: true
      services: {
        queue: {
          enabled: true
          keyType: 'Account'
        }
        table: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    isHnsEnabled: true
    isLocalUserEnabled: false
    isNfsV3Enabled: true
    isSftpEnabled: false
    largeFileSharesState: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      resourceAccessRules: []
      virtualNetworkRules: []
    }
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
  }
  sku: properties.sku
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
