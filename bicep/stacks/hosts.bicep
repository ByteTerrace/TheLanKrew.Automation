import * as id from '../modules/managed-identity/user-assigned-identities/main.bicep'
import * as ippre from '../modules/network/public-ip-prefixes/main.bicep'
import * as vmss from '../modules/compute/virtual-machine-scale-sets/main.bicep'

func generateDeploymentName(suffix string) string => '${deployment().name}-${suffix}'
func generateResourceName(
  abbreviation string,
  prefix string,
  suffix string
) string => '${prefix}-${abbreviation}-${suffix}'

param administrator {
  name: string
  @secure()
  password: string
}
param location string
param resourceNamePrefix string
param sharedImageGallery {
  name: string
  resourceGroupName: string?
  subscriptionId: string?
}
param subnet {
  name: string
  resourceGroupName: string?
  subscriptionId: string?
  virtualNetworkName: string
}

var names = {
  publicIpPrefixes: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(ippre.abbreviation, resourceNamePrefix, 'P000')
    '7DaysToDieDedicatedServer': generateResourceName(ippre.abbreviation, resourceNamePrefix, 'P001')
  }
  userAssignedIdentities: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(id.abbreviation, resourceNamePrefix, 'P001')
    '7DaysToDieDedicatedServer': generateResourceName(id.abbreviation, resourceNamePrefix, 'P002')
  }
  virtualMachineScaleSets: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(vmss.abbreviation, resourceNamePrefix, 'P000')
    '7DaysToDieDedicatedServer': generateResourceName(vmss.abbreviation, resourceNamePrefix, 'P001')
  }
}

module arkSurvivalEvolvedDedicatedServerPublicIpPrefix '../modules/network/public-ip-prefixes/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.publicIpPrefixes.arkSurvivalEvolvedDedicatedServer))
  params: {
    location: location
    properties: {
      length: 31
      name: names.publicIpPrefixes.arkSurvivalEvolvedDedicatedServer
      sku: {
        name: 'Standard'
        tier: 'Regional'
      }
      version: 'IPv4'
    }
  }
}
module arkSurvivalEvolvedDedicatedServerUserAssignedIdentity '../modules/managed-identity/user-assigned-identities/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.userAssignedIdentities.arkSurvivalEvolvedDedicatedServer))
  params: {
    location: location
    properties: {
      name: names.userAssignedIdentities.arkSurvivalEvolvedDedicatedServer
    }
  }
}
module arkSurvivalEvolvedDedicatedServerVirtualMachineScaleSet '../modules/compute/virtual-machine-scale-sets/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.virtualMachineScaleSets.arkSurvivalEvolvedDedicatedServer))
  params: {
    location: location
    properties: {
      administrator: administrator
      name: names.virtualMachineScaleSets.arkSurvivalEvolvedDedicatedServer
      identity: { userAssignedIdentities: [ arkSurvivalEvolvedDedicatedServerUserAssignedIdentity.outputs.properties ] }
      networking: {
        interfaces: [
          {
            ipConfigurations: [
              {
                isPrimary: true
                name: 'default'
                privateIpAddress: {
                  subnet: subnet
                  version: 'IPv4'
                }
                publicIpPrefix: arkSurvivalEvolvedDedicatedServerPublicIpPrefix.outputs.properties
              }
            ]
            isPrimary: true
            name: 'TLKRW-NIC'
          }
        ]
      }
      operatingSystem: {
        disk: {
          cacheMode: 'ReadOnly'
          sizeInGigabytes: 74
        }
        image: {
          gallery: sharedImageGallery
          name: 'WindowsServer2022-ArkSurvivalEvolvedDedicatedServerStable'
          version: 'latest'
        }
        type: 'Windows'
      }
      sku: {
        name: 'Standard_D2ds_v4'
      }
    }
  }
}

module _7DaysToDieDedicatedServerPublicIpPrefix '../modules/network/public-ip-prefixes/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.publicIpPrefixes['7DaysToDieDedicatedServer']))
  params: {
    location: location
    properties: {
      length: 31
      name: names.publicIpPrefixes['7DaysToDieDedicatedServer']
      sku: {
        name: 'Standard'
        tier: 'Regional'
      }
      version: 'IPv4'
    }
  }
}
module _7DaysToDieDedicatedServerUserAssignedIdentity '../modules/managed-identity/user-assigned-identities/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.userAssignedIdentities['7DaysToDieDedicatedServer']))
  params: {
    location: location
    properties: {
      name: names.userAssignedIdentities['7DaysToDieDedicatedServer']
    }
  }
}
module _7DaysToDieDedicatedServerVirtualMachineScaleSet '../modules/compute/virtual-machine-scale-sets/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.virtualMachineScaleSets['7DaysToDieDedicatedServer']))
  params: {
    location: location
    properties: {
      administrator: administrator
      name: names.virtualMachineScaleSets['7DaysToDieDedicatedServer']
      identity: { userAssignedIdentities: [ _7DaysToDieDedicatedServerUserAssignedIdentity.outputs.properties ] }
      networking: {
        interfaces: [
          {
            ipConfigurations: [
              {
                isPrimary: true
                name: 'default'
                privateIpAddress: {
                  subnet: subnet
                  version: 'IPv4'
                }
                publicIpPrefix: _7DaysToDieDedicatedServerPublicIpPrefix.outputs.properties
              }
            ]
            isPrimary: true
            name: 'TLKRW-NIC'
          }
        ]
      }
      operatingSystem: {
        disk: {
          cacheMode: 'ReadOnly'
          sizeInGigabytes: 74
        }
        image: {
          gallery: sharedImageGallery
          name: 'WindowsServerCore2022-7DaysToDieDedicatedServerStable'
          version: 'latest'
        }
        type: 'Windows'
      }
      sku: {
        name: 'Standard_D2ds_v4'
      }
    }
  }
}
