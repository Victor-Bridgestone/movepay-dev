param environment string
param developerGroupObjectId string
param qaGroupObjectId string
param businessUserGroupObjectId string
param devopsSpnObjectId string
param keyVaultName string
param storageAccountName string
param functionAppPrincipalId string
param logicAppPrincipalId string

var isDev  = environment == 'dev'
var isTest = environment == 'test'
var isProd = environment == 'prod'

var contributorRoleId           = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var readerRoleId                = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var kvSecretsUserRoleId         = '4633458b-17de-408a-b874-0445c86b69e6'
var kvSecretsOfficerRoleId      = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var storageBlobContribRoleId    = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var storageBlobReaderRoleId     = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var logicAppContribRoleId       = '87a39d53-fc1b-424a-814c-f7e04687dc9e'
var websiteContribRoleId        = 'de139f84-1756-47ae-9be6-808fbbe84772'


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

resource devGroupRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerGroupObjectId)) {
  name: guid(resourceGroup().id, developerGroupObjectId, isDev ? contributorRoleId : readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', isDev ? contributorRoleId : readerRoleId)
    principalId: developerGroupObjectId
    principalType: 'Group'
  }
}

resource qaGroupRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(qaGroupObjectId) && !isDev) {
  name: guid(resourceGroup().id, qaGroupObjectId, isTest ? contributorRoleId : readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', isTest ? contributorRoleId : readerRoleId)
    principalId: qaGroupObjectId
    principalType: 'Group'
  }
}

resource businessGroupRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(businessUserGroupObjectId) && !isDev) {
  name: guid(resourceGroup().id, businessUserGroupObjectId, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: businessUserGroupObjectId
    principalType: 'Group'
  }
}

resource devopsSpnRg 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(devopsSpnObjectId)) {
  name: guid(resourceGroup().id, devopsSpnObjectId, contributorRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: devopsSpnObjectId
    principalType: 'ServicePrincipal'
  }
}

resource funcAppKvUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(functionAppPrincipalId)) {
  name: guid(keyVault.id, functionAppPrincipalId, kvSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource logicAppKvUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(logicAppPrincipalId)) {
  name: guid(keyVault.id, logicAppPrincipalId, kvSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource logicAppStorageContrib 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(logicAppPrincipalId)) {
  name: guid(storageAccount.id, logicAppPrincipalId, storageBlobContribRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobContribRoleId)
    principalId: logicAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource funcAppStorageReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(functionAppPrincipalId)) {
  name: guid(storageAccount.id, functionAppPrincipalId, storageBlobReaderRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobReaderRoleId)
    principalId: functionAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}
