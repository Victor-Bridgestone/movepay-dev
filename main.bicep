param environment string

param location string = resourceGroup().location

param sqlAdminLogin string = 'sqladmin'

param sqlAdminPassword string

param developerGroupObjectId string = ''

param qaGroupObjectId string = ''

param businessUserGroupObjectId string = ''

param devopsSpnObjectId string = ''

var prefix = 'movepay-${environment}'
var isProd = environment == 'prod'
var isTest = environment == 'test'

module network 'modules/network.bicep' = {
  name: 'network-${environment}'
  params: {
    prefix: prefix
    location: location
    environment: environment
  }
}

module keyvault 'modules/keyvault.bicep' = {
  name: 'keyvault-${environment}'
  params: {
    prefix: prefix
    location: location
    developerGroupObjectId: developerGroupObjectId
    devopsSpnObjectId: devopsSpnObjectId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage-${environment}'
  params: {
    prefix: prefix
    location: location
    environment: environment
    subnetId: network.outputs.storageSubnetId
    keyVaultId: keyvault.outputs.keyVaultId
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql-${environment}'
  params: {
    prefix: prefix
    location: location
    environment: environment
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    subnetId: network.outputs.dbSubnetId
    keyVaultName: keyvault.outputs.keyVaultName
  }
}

module functionapp 'modules/functionapp.bicep' = {
  name: 'functionapp-${environment}'
  params: {
    prefix: prefix
    location: location
    environment: environment
    storageAccountName: storage.outputs.storageAccountName
    subnetId: network.outputs.functionsSubnetId
    keyVaultName: keyvault.outputs.keyVaultName
  }
}

module logicapp 'modules/logicapp.bicep' = {
  name: 'logicapp-${environment}'
  params: {
    prefix: prefix
    location: location
    storageAccountName: storage.outputs.storageAccountName
    storageAccountKey: storage.outputs.storageAccountKey
    containerName: storage.outputs.containerName
    functionAppUrl: functionapp.outputs.functionAppUrl
    keyVaultName: keyvault.outputs.keyVaultName
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-${environment}'
  params: {
    prefix: prefix
    location: location
    functionAppName: functionapp.outputs.functionAppName
    logicAppName: logicapp.outputs.logicAppName
  }
}

module roles 'modules/roles.bicep' = {
  name: 'roles-${environment}'
  params: {
    environment: environment
    developerGroupObjectId: developerGroupObjectId
    qaGroupObjectId: qaGroupObjectId
    businessUserGroupObjectId: businessUserGroupObjectId
    devopsSpnObjectId: devopsSpnObjectId
    keyVaultName: keyvault.outputs.keyVaultName
    storageAccountName: storage.outputs.storageAccountName
    functionAppPrincipalId: functionapp.outputs.functionAppPrincipalId
    logicAppPrincipalId: logicapp.outputs.logicAppPrincipalId
  }
}

output resourceGroupName string = resourceGroup().name
output functionAppName string = functionapp.outputs.functionAppName
output functionAppUrl string = functionapp.outputs.functionAppUrl
output logicAppName string = logicapp.outputs.logicAppName
output sqlServerFqdn string = sql.outputs.sqlServerFqdn
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultName string = keyvault.outputs.keyVaultName
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
