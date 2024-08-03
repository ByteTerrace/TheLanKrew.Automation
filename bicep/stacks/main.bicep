/*

    - https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
    - https://learn.microsoft.com/en-us/windows-server/get-started/hotpatch
    - https://learn.microsoft.com/en-us/windows-server/get-started/server-core-app-compatibility-feature-on-demand

*/

import * as gal from '../modules/compute/galleries/main.bicep'
import * as id from '../modules/managed-identity/user-assigned-identities/main.bicep'
import * as ippre from '../modules/network/public-ip-prefixes/main.bicep'
import * as it from '../modules/virtual-machine-images/image-templates/main.bicep'
import * as nsg from '../modules/network/network-security-groups/main.bicep'
import * as snet from '../modules/network/subnets/main.bicep'
import * as vmss from '../modules/compute/virtual-machine-scale-sets/main.bicep'
import * as vnet from '../modules/network/virtual-networks/main.bicep'

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
param virtualNetwork {
  addressPrefixes: string[]
  subnets: {
    containerInstances: {
      addressPrefixes: string[]
    }
    hostVirtualMachines: {
      addressPrefixes: string[]
    }
    imageBuilder: {
      addressPrefixes: string[]
    }
  }
}

var names = {
  computeGallery: generateResourceName(gal.abbreviation, resourceNamePrefix, 'P000')
  imageTemplates: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(it.abbreviation, resourceNamePrefix, 'P000')
    '7DaysToDieDedicatedServer': generateResourceName(it.abbreviation, resourceNamePrefix, 'P001')
  }
  networkSecurityGroups: {
    containerInstances: generateResourceName(nsg.abbreviation, resourceNamePrefix, 'P002')
    hostVirtualMachines: generateResourceName(nsg.abbreviation, resourceNamePrefix, 'P000')
    imageBuildVirtualMachines: generateResourceName(nsg.abbreviation, resourceNamePrefix, 'P001')
  }
  publicIpPrefixes: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(ippre.abbreviation, resourceNamePrefix, 'P000')
    '7DaysToDieDedicatedServer': generateResourceName(ippre.abbreviation, resourceNamePrefix, 'P001')
  }
  subnets: {
    containerInstances: generateResourceName(snet.abbreviation, resourceNamePrefix, 'P002')
    hostVirtualMachines: generateResourceName(snet.abbreviation, resourceNamePrefix, 'P000')
    imageBuildVirtualMachines: generateResourceName(snet.abbreviation, resourceNamePrefix, 'P001')
  }
  userAssignedIdentities: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(id.abbreviation, resourceNamePrefix, 'P001')
    imageBuildVirtualMachines: generateResourceName(id.abbreviation, resourceNamePrefix, 'P000')
    '7DaysToDieDedicatedServer': generateResourceName(id.abbreviation, resourceNamePrefix, 'P002')
  }
  virtualMachineScaleSets: {
    arkSurvivalEvolvedDedicatedServer: generateResourceName(vmss.abbreviation, resourceNamePrefix, 'P000')
    '7DaysToDieDedicatedServer': generateResourceName(vmss.abbreviation, resourceNamePrefix, 'P001')
  }
  virtualNetwork: generateResourceName(vnet.abbreviation, resourceNamePrefix, 'P000')
}

// shared resources
module containerInstancesNetworkSecurityGroup '../modules/network/network-security-groups/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.networkSecurityGroups.containerInstances))
  params: {
    location: location
    properties: {
      name: names.networkSecurityGroups.containerInstances
      rules: []
    }
  }
}
module containerInstancesSubnet '../modules/network/subnets/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.subnets.containerInstances))
  params: {
    properties: {
      addressPrefixes: virtualNetwork.subnets.containerInstances.addressPrefixes
      delegations: [ 'Microsoft.ContainerInstance/containerGroups' ]
      name: names.subnets.containerInstances
      roleAssignments: [
        {
          principalId: imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties.principalId
          roleDefinitionId: '571ea911-7d02-493d-a67b-06258220ae5f'
        }
      ]
      networkSecurityGroup: containerInstancesNetworkSecurityGroup.outputs.properties
      virtualNetworkName: sharedVirtualNetwork.outputs.properties.name
    }
  }
}
module hostVirtualMachinesNetworkSecurityGroup '../modules/network/network-security-groups/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.networkSecurityGroups.hostVirtualMachines))
  params: {
    location: location
    properties: {
      name: names.networkSecurityGroups.hostVirtualMachines
      rules: [
        {
          access: 'Allow'
          destination: {
            addressPrefixes: virtualNetwork.subnets.hostVirtualMachines.addressPrefixes
            ports: [ '26900' ]
          }
          direction: 'Inbound'
          name: 'Allow7DaysToDieTcpInbound'
          priority: 2049
          protocol: 'Tcp'
          source: {
            addressPrefixes: [ '*' ]
            ports: [ '*' ]
          }
        }
        {
          access: 'Allow'
          destination: {
            addressPrefixes: virtualNetwork.subnets.hostVirtualMachines.addressPrefixes
            ports: [ '26900-26903' ]
          }
          direction: 'Inbound'
          name: 'Allow7DaysToDieUdpInbound'
          priority: 2050
          protocol: 'Udp'
          source: {
            addressPrefixes: [ '*' ]
            ports: [ '*' ]
          }
        }
        {
          access: 'Allow'
          destination: {
            addressPrefixes: virtualNetwork.subnets.hostVirtualMachines.addressPrefixes
            ports: [
              '7777-7778'
              '27015'
            ]
          }
          direction: 'Inbound'
          name: 'AllowArkSurvivalEvolvedUdpInbound'
          priority: 2051
          protocol: 'Udp'
          source: {
            addressPrefixes: [ '*' ]
            ports: [ '*' ]
          }
        }
      ]
    }
  }
}
module hostVirtualMachinesSubnet '../modules/network/subnets/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.subnets.hostVirtualMachines))
  params: {
    properties: {
      addressPrefixes: virtualNetwork.subnets.hostVirtualMachines.addressPrefixes
      name: names.subnets.hostVirtualMachines
      networkSecurityGroup: hostVirtualMachinesNetworkSecurityGroup.outputs.properties
      virtualNetworkName: sharedVirtualNetwork.outputs.properties.name
    }
  }
}
module imageBuildVirtualMachinesNetworkSecurityGroup '../modules/network/network-security-groups/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.networkSecurityGroups.imageBuildVirtualMachines))
  params: {
    location: location
    properties: {
      name: names.networkSecurityGroups.imageBuildVirtualMachines
      rules: [
        {
          access: 'Allow'
          destination: {
            addressPrefixes: virtualNetwork.subnets.imageBuilder.addressPrefixes
            ports: [ '60000-60001' ]
          }
          direction: 'Inbound'
          name: 'AllowAzureImageBuilderTcpInbound'
          priority: 2049
          protocol: 'Tcp'
          source: {
            addressPrefixes: [ 'AzureLoadBalancer' ]
            ports: [ '*' ]
          }
        }
      ]
    }
  }
}
module imageBuildVirtualMachinesSubnet '../modules/network/subnets/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.subnets.imageBuildVirtualMachines))
  params: {
    properties: {
      addressPrefixes: virtualNetwork.subnets.imageBuilder.addressPrefixes
      isDefaultOutboundAccessEnabled: true
      isPrivateEndpointNetworkPolicyEnabled: true
      isPrivateLinkServiceNetworkPolicyEnabled: false
      name: names.subnets.imageBuildVirtualMachines
      networkSecurityGroup: imageBuildVirtualMachinesNetworkSecurityGroup.outputs.properties
      roleAssignments: [
        {
          principalId: imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties.principalId
          roleDefinitionId: '571ea911-7d02-493d-a67b-06258220ae5f'
        }
      ]
      virtualNetworkName: sharedVirtualNetwork.outputs.properties.name
    }
  }
}
module imageBuildVirtualMachinesUserAssignedIdentity '../modules/managed-identity/user-assigned-identities/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.userAssignedIdentities.imageBuildVirtualMachines))
  params: {
    location: location
    properties: {
      name: names.userAssignedIdentities.imageBuildVirtualMachines
      roleAssignments: [
        {
          roleDefinitionId: '30e715a4-69de-4e04-98f8-5f3bbea9655d'
        }
      ]
    }
  }
}
module sharedComputeGallery '../modules/compute/galleries/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.computeGallery))
  params: {
    properties: {
      images: [
        {
          architecture: 'x64'
          generation: 'V2'
          identifier: {
            offer: 'WindowsServer2022'
            publisher: 'ByteTerrace'
            sku: 'ArkSurvivalEvolvedDedicatedServerStable'
          }
          name: 'WindowsServer2022-ArkSurvivalEvolvedDedicatedServerStable'
          roleAssignments: [
            {
              principalId: imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties.principalId
              roleDefinitionId: '6cad5fb0-4ac3-44d6-9d7e-535680920ad1'
            }
          ]
        }
        {
          architecture: 'x64'
          generation: 'V2'
          identifier: {
            offer: 'WindowsServer2022'
            publisher: 'ByteTerrace'
            sku: '7DaysToDieDedicatedServerStable'
          }
          name: 'WindowsServerCore2022-7DaysToDieDedicatedServerStable'
          roleAssignments: [
            {
              principalId: imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties.principalId
              roleDefinitionId: '6cad5fb0-4ac3-44d6-9d7e-535680920ad1'
            }
          ]
        }
      ]
      name: names.computeGallery
    }
  }
}
module sharedVirtualNetwork '../modules/network/virtual-networks/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.virtualNetwork))
  params: {
    location: location
    properties: {
      addressPrefixes: virtualNetwork.addressPrefixes
      name: names.virtualNetwork
      roleAssignments: [
        {
          principalId: imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties.principalId
          roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
        }
      ]
    }
  }
}

// host resources
module arkSurvivalEvolvedDedicatedServerImageTemplate '../modules/virtual-machine-images/image-templates/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.imageTemplates.arkSurvivalEvolvedDedicatedServer))
  params: {
    location: location
    properties: {
      customizations: [
        {
          inline: [ 'New-Item -ItemType \'Directory\' -Path \'C:/ByteTerrace/PowerShell\' | Out-Null' ]
          name: 'Create Staging Path'
          type: 'PowerShell'
        }
        {
          destination: 'C:/ByteTerrace/PowerShell/Install-PowerShell.ps1'
          name: 'Download Install-PowerShell.ps1'
          sourceUri: 'https://byteterrace.blob.core.windows.net/temp/PowerShell/Install-PowerShell.ps1'
          type: 'File'
        }
        {
          inline: [ '&\'C:/ByteTerrace/PowerShell/Install-PowerShell.ps1\'' ]
          name: 'Run Install-PowerShell.ps1'
          type: 'PowerShell'
        }
        {
          destination: 'C:/ByteTerrace/PowerShell/New-AzureStorageSymbolicLink.ps1'
          name: 'Download New-AzureStorageSymbolicLink.ps1'
          sourceUri: 'https://byteterrace.blob.core.windows.net/temp/PowerShell/New-AzureStorageSymbolicLink.ps1'
          type: 'File'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/PowerShell/New-AzureStorageSymbolicLink.ps1\' -GlobalMapping -LocalPath \'C:/ByteTerrace/NetworkShare\' -Persistent -StorageAccountFileSharePath \'\\\\byteterrace.file.core.windows.net\\temp\' -StorageAccountName \'byteterrace\' -StorageAccountResourceGroupName \'byteterrace\' -StorageAccountSubscriptionId \'fd49ea67-135b-449f-a62c-3e4b8d26d3d6\'; exit $LASTEXITCODE; }' ]
          name: 'Run New-AzureStorageSymbolicLink.ps1'
          type: 'PowerShell'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/NetworkShare/Ark Survival Evolved/Install-ArkSurvivalEvolvedServerDependencies.ps1\'; exit $LASTEXITCODE; }']
          name: 'Run Install-ArkSurvivalEvolvedServerDependencies.ps1'
          runAsSystem: true
          runElevated: true
          type: 'PowerShell'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/NetworkShare/Steam/Install-SteamApp.ps1\' -Arguments \'validate\' -SteamAppId \'376030\' -SteamCmdBasePath \'C:/ByteTerrace/Steam\'; exit $LASTEXITCODE; }' ]
          name: 'Run Install-SteamApp.ps1'
          type: 'PowerShell'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { Remove-SmbMapping -Confirm:$false -GlobalMapping -RemotePath \'\\\\byteterrace.file.core.windows.net\\temp\'; exit 0; }']
          name: 'Remove Saved Credentials'
          type: 'PowerShell'
        }
      ]
      name: names.imageTemplates.arkSurvivalEvolvedDedicatedServer
      identity: { userAssignedIdentities: [ imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties ] }
      networking: {
        containerInstanceSubnet: containerInstancesSubnet.outputs.properties
        subnet: imageBuildVirtualMachinesSubnet.outputs.properties
      }
      source: {
        offer: 'WindowsServer'
        publisher: 'MicrosoftWindowsServer'
        sku: '2022-datacenter-azure-edition-smalldisk'
        type: 'PlatformImage'
        version: 'latest'
      }
      target: {
        computeGallery: sharedComputeGallery.outputs.properties
        name: 'WindowsServer2022-ArkSurvivalEvolvedDedicatedServerStable'
        outputName: 'WindowsServer2022-ArkSurvivalEvolvedDedicatedServerStable'
      }
    }
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
  dependsOn: [ arkSurvivalEvolvedDedicatedServerImageTemplate ]
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
                  subnet: hostVirtualMachinesSubnet.outputs.properties
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
          gallery: {
            name: sharedComputeGallery.outputs.properties.name
          }
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
module _7DaysToDieDedicatedServerImageTemplate '../modules/virtual-machine-images/image-templates/main.bicep' = {
  name: generateDeploymentName(uniqueString(names.imageTemplates['7DaysToDieDedicatedServer']))
  params: {
    location: location
    properties: {
      customizations: [
        {
          inline: [ 'New-Item -ItemType \'Directory\' -Path \'C:/ByteTerrace/PowerShell\' | Out-Null' ]
          name: 'Create Staging Path'
          type: 'PowerShell'
        }
        {
          destination: 'C:/ByteTerrace/PowerShell/Install-PowerShell.ps1'
          name: 'Download Install-PowerShell.ps1'
          sourceUri: 'https://byteterrace.blob.core.windows.net/temp/PowerShell/Install-PowerShell.ps1'
          type: 'File'
        }
        {
          inline: [ '&\'C:/ByteTerrace/PowerShell/Install-PowerShell.ps1\'' ]
          name: 'Run Install-PowerShell.ps1'
          type: 'PowerShell'
        }
        {
          destination: 'C:/ByteTerrace/PowerShell/New-AzureStorageSymbolicLink.ps1'
          name: 'Download New-AzureStorageSymbolicLink.ps1'
          sourceUri: 'https://byteterrace.blob.core.windows.net/temp/PowerShell/New-AzureStorageSymbolicLink.ps1'
          type: 'File'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/PowerShell/New-AzureStorageSymbolicLink.ps1\' -GlobalMapping -LocalPath \'C:/ByteTerrace/NetworkShare\' -Persistent -StorageAccountFileSharePath \'\\\\byteterrace.file.core.windows.net\\temp\' -StorageAccountName \'byteterrace\' -StorageAccountResourceGroupName \'byteterrace\' -StorageAccountSubscriptionId \'fd49ea67-135b-449f-a62c-3e4b8d26d3d6\'; exit $LASTEXITCODE; }' ]
          name: 'Run New-AzureStorageSymbolicLink.ps1'
          type: 'PowerShell'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/NetworkShare/PowerShell/Install-WindowsServerCoreAppCompatibilityFeature.ps1\'; exit $LASTEXITCODE; }' ]
          name: 'Run Install-WindowsServerCoreAppCompatibilityFeature.ps1'
          runElevated: true
          type: 'PowerShell'
        }
        {
          name: 'First Restart Operation'
          type: 'WindowsRestart'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/NetworkShare/7 Days to Die/Install-7DaysToDieServerDependencies.ps1\'; exit $LASTEXITCODE; }']
          name: 'Run Install-7DaysToDieServerDependencies.ps1'
          runAsSystem: true
          runElevated: true
          type: 'PowerShell'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { &\'C:/ByteTerrace/NetworkShare/Steam/Install-SteamApp.ps1\' -Arguments \'validate\' -SteamAppId \'294420\' -SteamCmdBasePath \'C:/ByteTerrace/Steam\'; exit $LASTEXITCODE; }' ]
          name: 'Run Install-SteamApp.ps1'
          type: 'PowerShell'
        }
        {
          inline: [ 'pwsh -NonInteractive -NoProfile -Command { Remove-SmbMapping -Confirm:$false -GlobalMapping -RemotePath \'\\\\byteterrace.file.core.windows.net\\temp\'; exit 0; }']
          name: 'Remove Saved Credentials'
          type: 'PowerShell'
        }
      ]
      name: names.imageTemplates['7DaysToDieDedicatedServer']
      identity: { userAssignedIdentities: [ imageBuildVirtualMachinesUserAssignedIdentity.outputs.properties ] }
      networking: {
        containerInstanceSubnet: containerInstancesSubnet.outputs.properties
        subnet: imageBuildVirtualMachinesSubnet.outputs.properties
      }
      source: {
        offer: 'WindowsServer'
        publisher: 'MicrosoftWindowsServer'
        sku: '2022-datacenter-azure-edition-core-smalldisk'
        type: 'PlatformImage'
        version: 'latest'
      }
      target: {
        computeGallery: sharedComputeGallery.outputs.properties
        name: 'WindowsServerCore2022-7DaysToDieDedicatedServerStable'
        outputName: 'WindowsServerCore2022-7DaysToDieDedicatedServerStable'
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
  dependsOn: [ _7DaysToDieDedicatedServerImageTemplate ]
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
                  subnet: hostVirtualMachinesSubnet.outputs.properties
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
          gallery: {
            name: sharedComputeGallery.outputs.properties.name
          }
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
