param prefix string
param location string
param environment string
param storageAccountName string
param subnetId string
param keyVaultName string

var isProd = environment == 'prod'

resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'asp-${prefix}-functions'
  location: location
  sku: {
    name: isProd ? 'EP1' : 'Y1'
    tier: isProd ? 'ElasticPremium' : 'Dynamic'
  }
  kind: 'functionapp'
  properties: {
    reserved: true 
  }
}


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: 'func-${prefix}'
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Python|3.10'
      pythonVersion: '3.10'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower('func-${prefix}')
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'ENVIRONMENT'
          value: environment
        }
        {
          name: 'SQL_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=sql-connection-string)'
        }
      ]
      vnetRouteAllEnabled: isProd ? true : false
    }
    virtualNetworkSubnetId: isProd ? subnetId : null
  }
}

output functionAppId string = functionApp.id
output functionAppName string = functionApp.name
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppPrincipalId string = functionApp.identity.principalId
