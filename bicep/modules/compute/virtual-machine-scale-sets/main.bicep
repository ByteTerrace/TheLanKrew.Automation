import { createIdentityObject, } from '../../../functions/main.bicep'

param location string = resourceGroup().location
param properties {
  administrator: {
    name: string
    @secure()
    password: string
  }
  identity: {
    userAssignedIdentities: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
    }[]
  }
  name: string
  networking: {
    interfaces: {
      ipConfigurations: {
        isPrimary: bool
        name: string
        privateIpAddress: {
          subnet: {
            name: string
            resourceGroupName: string?
            subscriptionId: string?
            virtualNetworkName: string
          }
          version: ('IPv4' | 'IPv6')
        }
        publicIpAddress: {
          name: string
          sku: {
            name: 'Standard'
            tier: 'Regional'
          }
          version: ('IPv4' | 'IPv6')
        }?
        publicIpPrefix: {
          name: string
          resourceGroupName: string?
          subscriptionId: string?
        }?
      }[]
      isPrimary: bool
      name: string
      networkSecurityGroup: {
        name: string
        resourceGroupName: string?
        subscriptionId: string?
      }?
    }[]
  }
  operatingSystem: {
    disk: {
      cacheMode: ('None' | 'ReadOnly' | 'ReadWrite')
      sizeInGigabytes: int?
      isEphemeral: bool?
      isWriteAcceleratorEnabled: bool?
    }
    image: {
      gallery: {
        name: string
        resourceGroupName: string?
        subscriptionId: string?
      }?
      name: string?
      offer: 'WindowsServer'?
      publisher: 'MicrosoftWindowsServer'?
      sku: string?
      version: 'latest'
    }
    type: ('Linux' | 'Windows')
  }
  sku: {
    name: string
  }
}

@export()
var abbreviation = 'VMSS'
var name = properties.name

resource virtualMachineScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-03-01' = {
  identity: createIdentityObject(false, properties.identity.userAssignedIdentities)
  location: location
  name: properties.name
  properties: {
    additionalCapabilities: {
      hibernationEnabled: false
      ultraSSDEnabled: false
    }
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    priorityMixPolicy: {
      baseRegularPriorityCount: 0
      regularPriorityPercentageAboveBase: 0
    }
    virtualMachineProfile: {
      evictionPolicy: 'Delete'
      extensionProfile: {
        extensions: [
          {
            name: 'ApplicationHealth'
            properties: {
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              provisionAfterExtensions: [
                'GuestAttestation'
              ]
              publisher: 'Microsoft.ManagedServices'
              settings: {
                intervalInSeconds: 60
                numberOfProbes: 1
                port: 443
                protocol: 'https'
                requestPath: '/health-check'
              }
              suppressFailures: false
              type: 'ApplicationHealthWindows'
              typeHandlerVersion: '2.0'
            }
          }
          {
            name: 'GuestAttestation'
            properties: {
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: true
              publisher: 'Microsoft.Azure.Security.WindowsAttestation'
              settings: {
                AttestationConfig: {
                  AscSettings: {
                    ascReportingEndpoint: ''
                    ascReportingFrequency: ''
                  }
                  MaaSettings: {
                    maaEndpoint: ''
                    maaTenantName: 'GuestAttestation'
                  }
                  disableAlerts: 'false'
                  useCustomToken: 'false'
                }
              }
              suppressFailures: false
              type: 'GuestAttestation'
              typeHandlerVersion: '1.0'
            }
          }
          {
            name: 'OpenSSH'
            properties: {
              autoUpgradeMinorVersion: true
              enableAutomaticUpgrade: false
              provisionAfterExtensions: [
                'GuestAttestation'
              ]
              publisher: 'Microsoft.Azure.OpenSSH'
              suppressFailures: false
              type: 'WindowsOpenSSH'
              typeHandlerVersion: '3.0'
            }
          }
        ]
        extensionsTimeBudget: 'PT23M'
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [for (interfaceConfiguration, index) in properties.networking.interfaces: {
          name: interfaceConfiguration.name
          properties: {
            deleteOption: 'Delete'
            enableAcceleratedNetworking: true
            enableIPForwarding: false
            ipConfigurations: map(interfaceConfiguration.ipConfigurations, ipConfiguration => {
              name: ipConfiguration.name
              properties: {
                applicationSecurityGroups: []
                primary: ipConfiguration.isPrimary
                privateIPAddressVersion: ipConfiguration.privateIpAddress.version
                publicIPAddressConfiguration: (contains(ipConfiguration, 'publicIpAddress') ? {
                  name: ipConfiguration.publicIpAddress!.name
                  properties: {
                    deleteOption: 'Delete'
                    idleTimeoutInMinutes: 4
                    publicIPAddressVersion: ipConfiguration.publicIpAddress!.version
                  }
                  sku: ipConfiguration.publicIpAddress!.sku
                } : (contains(ipConfiguration, 'publicIpPrefix') ? {
                  name: ipConfiguration.publicIpPrefix!.name
                  properties: {
                    publicIPPrefix: {
                      id: resourceId(
                        (ipConfiguration.publicIpPrefix.?subscriptionId ?? subscription().subscriptionId),
                        (ipConfiguration.publicIpPrefix.?resourceGroupName ?? resourceGroup().name),
                        'Microsoft.Network/publicIPPrefixes',
                        ipConfiguration.publicIpPrefix!.name
                      )
                    }
                  }
                } : null))
                subnet: {
                  id: resourceId(
                    (ipConfiguration.privateIpAddress.subnet.?subscriptionId ?? subscription().subscriptionId),
                    (ipConfiguration.privateIpAddress.subnet.?resourceGroupName ?? resourceGroup().name),
                    'Microsoft.Network/virtualNetworks/subnets',
                    ipConfiguration.privateIpAddress.subnet.virtualNetworkName,
                    ipConfiguration.privateIpAddress.subnet.name
                  )
                }
              }
            })
            networkSecurityGroup: (contains(interfaceConfiguration, 'networkSecurityGroup') ? {
              id: resourceId(
                (interfaceConfiguration.networkSecurityGroup.?subscriptionId ?? subscription().subscriptionId),
                (interfaceConfiguration.networkSecurityGroup.?resourceGroupName ?? resourceGroup().name),
                'Microsoft.Network/networkSecurityGroups',
                interfaceConfiguration.networkSecurityGroup!.name
              )
            } : null)
            primary: interfaceConfiguration.isPrimary
          }
        }]
      }
      osProfile: {
        adminPassword: properties.administrator.password
        adminUsername: properties.administrator.name
        computerNamePrefix: toUpper(take(uniqueString(name), 9))
        windowsConfiguration: {
          patchSettings: {
            assessmentMode: 'ImageDefault'
            /*automaticByPlatformSettings: {
              bypassPlatformSafetyChecksOnUserSchedule: false
              rebootSetting: 'Never'
            }*/
            enableHotpatching: false
            patchMode: 'AutomaticByOS'
          }
          provisionVMAgent: true
          timeZone: 'UTC'
        }
      }
      priority: 'Spot'
      securityProfile: {
        encryptionAtHost: true
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
      storageProfile: {
        dataDisks: []
        imageReference: (contains(properties.operatingSystem.image, 'gallery') ? {
          id: resourceId(
            (properties.operatingSystem.image.gallery.?subscriptionId ?? subscription().subscriptionId),
            (properties.operatingSystem.image.gallery.?resourceGroupName ?? resourceGroup().name),
            'Microsoft.Compute/galleries/images/versions',
            properties.operatingSystem.image.gallery!.name,
            properties.operatingSystem.image.name!,
            properties.operatingSystem.image.version
          )
        } : {
          offer: properties.operatingSystem.image.offer
          publisher: properties.operatingSystem.image.publisher
          sku: properties.operatingSystem.image.sku
          version: properties.operatingSystem.image.version
        })
        osDisk: {
          caching: properties.operatingSystem.disk.cacheMode
          createOption: 'FromImage'
          deleteOption: 'Delete'
          diffDiskSettings: ((properties.operatingSystem.disk.?isEphemeral ?? true) ? {
            option: 'Local'
            placement: 'ResourceDisk'
          } : null)
          diskSizeGB: properties.operatingSystem.disk.?sizeInGigabytes
          osType: properties.operatingSystem.type
          writeAcceleratorEnabled: (properties.operatingSystem.disk.?isWriteAcceleratorEnabled ?? false)
        }
      }
    }
  }
  sku: properties.sku
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
