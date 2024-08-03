param location string = resourceGroup().location
param properties {
  name: string
}

var name = properties.name

resource sshPublicKey 'Microsoft.Compute/sshPublicKeys@2024-03-01' = {
  location: location
  name: name
  properties: {
    publicKey: null
  }
}
