import { createIdentityObject, } from '../../../functions/main.bicep'

@discriminator('type')
type imageTemplateCustomizer = (imageTemplateCustomizerForFile | imageTemplateCustomizerForPowerShell | imageTemplateCustomizerForWindowsRestart)
type imageTemplateCustomizerForFile = {
  destination: string
  name: string
  sourceUri: string
  type: 'File'
}
type imageTemplateCustomizerForPowerShell = {
  inline: string[]
  name: string
  runAsSystem: bool?
  runElevated: bool?
  type: 'PowerShell'
}
type imageTemplateCustomizerForWindowsRestart = {
  name: string
  type: 'WindowsRestart'
}

@discriminator('type')
type imageTemplateSource = (imageTemplateSourceForPlatformImage | imageTemplateSourceForSharedImage)
type imageTemplateSourceForPlatformImage = {
  offer: 'WindowsServer'
  publisher: 'MicrosoftWindowsServer'
  type: 'PlatformImage'
  sku: ('2022-datacenter-azure-edition-smalldisk' | '2022-datacenter-azure-edition-core-smalldisk')
  version: 'latest'
}
type imageTemplateSourceForSharedImage = {
  computeGallery: {
    name: string
    resourceGroupName: string?
    subscriptionId: string?
  }
  name: string
  type: 'SharedImage'
  version: string
}

param location string = resourceGroup().location
param properties {
  customizations: imageTemplateCustomizer[]
  identity: {
    userAssignedIdentities: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
    }[]
  }
  name: string
  source: imageTemplateSource
  networking: {
    containerInstanceSubnet: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
      virtualNetworkName: string
    }
    subnet: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
      virtualNetworkName: string
    }
  }
  target: {
    computeGallery: {
      name: string
      resourceGroupName: string?
      subscriptionId: string?
    }
    name: string
    outputName: string
  }
}

@export()
var abbreviation = 'IT'
var identity = createIdentityObject(false, properties.identity.userAssignedIdentities)
var name = properties.name

resource imageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2024-02-01' = {
  identity: identity
  location: location
  name: name
  properties: {
    autoRun: {
      state: 'Enabled'
    }
    buildTimeoutInMinutes: 180
    customize: properties.customizations
    distribute: [
      {
        artifactTags: {}
        excludeFromLatest: false
        galleryImageId: resourceId(
          (properties.target.computeGallery.?subscriptionId ?? subscription().subscriptionId),
          (properties.target.computeGallery.?resourceGroupName ?? resourceGroup().name),
          'Microsoft.Compute/galleries/images',
          properties.target.computeGallery.name,
          properties.target.name
        )
        runOutputName: properties.target.outputName
        targetRegions: [
          {
            name: location
            storageAccountType: 'Standard_LRS'
          }
        ]
        type: 'SharedImage'
        versioning: {
          major: -1
          scheme: 'Latest'
        }
      }
    ]
    errorHandling: {
      onCustomizerError: 'cleanup'
      onValidationError: 'cleanup'
    }
    optimize: {
      vmBoot: {
        state: 'Enabled'
      }
    }
    source: (('SharedImage' == properties.source.type) ? {
      imageVersionId: resourceId(
        'Microsoft.Compute/galleries/images/versions',
        properties.source.computeGallery.name,
        properties.source.name,
        properties.source.version
      )
      type: 'SharedImageVersion'
    } : properties.source)
    validate: {
      continueDistributeOnFailure: false
      inVMValidations: []
      sourceValidationOnly: false
    }
    vmProfile: {
      osDiskSizeGB: 64
      userAssignedIdentities: [for identity in properties.identity.userAssignedIdentities: resourceId(
        (identity.?subscriptionId ?? subscription().subscriptionId),
        (identity.?resourceGroupName ?? resourceGroup().name),
        'Microsoft.ManagedIdentity/userAssignedIdentities',
        identity.name
      )]
      vmSize: 'Standard_D4ds_v4'
      vnetConfig: {
        containerInstanceSubnetId: resourceId(
          (properties.networking.containerInstanceSubnet.?subscriptionId ?? subscription().subscriptionId),
          (properties.networking.containerInstanceSubnet.?resourceGroupName ?? resourceGroup().name),
          'Microsoft.Network/virtualNetworks/subnets',
          properties.networking.containerInstanceSubnet.virtualNetworkName,
          properties.networking.containerInstanceSubnet.name
        )
        subnetId: resourceId(
          (properties.networking.subnet.?subscriptionId ?? subscription().subscriptionId),
          (properties.networking.subnet.?resourceGroupName ?? resourceGroup().name),
          'Microsoft.Network/virtualNetworks/subnets',
          properties.networking.subnet.virtualNetworkName,
          properties.networking.subnet.name
        )
      }
    }
  }
}

output properties object = {
  name: name
  resourceGroupName: resourceGroup().name
  subscriptionId: subscription().subscriptionId
}
