param prefix string
param location string
param environment string
param subnetId string
param keyVaultId string

var isProd = environment == 'prod'

var saName = toLower(take(replace(replace(prefix, '-', ''), '_', ''), 20) + 'sa')

var storageRedundancy = isProd ? 'Standard_GRS' : 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: saName
  location: location
  sku: { name: storageRedundancy }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: isProd ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
  }
}


resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'payment-storage-logic'
  properties: {
    publicAccess: 'None'
  }
}


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (isProd) {
  name: 'pe-storage-${prefix}'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-storage-${prefix}'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}


resource kvRef 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: last(split(keyVaultId, '/'))
}

resource storageKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kvRef
  name: 'storage-account-key'
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}


output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output containerName string = container.name
output storageAccountKey string = storageAccount.listKeys().keys[0].value
