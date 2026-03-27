param prefix string
param location string
param environment string
param adminLogin string
param adminPassword string
param subnetId string
param keyVaultName string

var isProd = environment == 'prod'

var sqlTier    = isProd ? 'GeneralPurpose' : 'Basic'
var sqlFamily  = isProd ? 'Gen5' : ''
var sqlCapacity = isProd ? 4 : 5


resource sqlServer 'Microsoft.Sql/servers@2023-02-01-preview' = {
  name: 'sql-${prefix}'
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: isProd ? 'Disabled' : 'Enabled'
  }
}

resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2023-02-01-preview' = if (!isProd) {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}


resource sqlDb 'Microsoft.Sql/servers/databases@2023-02-01-preview' = {
  parent: sqlServer
  name: 'db-${prefix}-payments'
  location: location
  sku: {
    name: sqlTier
    tier: sqlTier
    family: empty(sqlFamily) ? null : sqlFamily
    capacity: sqlCapacity
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: isProd ? 34359738368 : 2147483648
    zoneRedundant: false
    requestedBackupStorageRedundancy: isProd ? 'Geo' : 'Local'
  }
}


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (isProd) {
  name: 'pe-sql-${prefix}'
  location: location
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-sql-${prefix}'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: ['sqlServer']
        }
      }
    ]
  }
}


resource kvRef 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource sqlConnSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kvRef
  name: 'sql-connection-string'
  properties: {
    value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDb.name};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;'
  }
}

resource sqlAdminPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kvRef
  name: 'sql-admin-password'
  properties: {
    value: adminPassword
  }
}


output sqlServerId string = sqlServer.id
output sqlServerName string = sqlServer.name
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDbName string = sqlDb.name
