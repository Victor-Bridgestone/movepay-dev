param prefix string
param location string
param developerGroupObjectId string
param devopsSpnObjectId string

var kvName = 'kv-${take(replace(prefix, '-', ''), 18)}'

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

var kvSecretsOfficerRoleId = 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource devSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(developerGroupObjectId)) {
  name: guid(keyVault.id, developerGroupObjectId, kvSecretsOfficerRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsOfficerRoleId)
    principalId: developerGroupObjectId
    principalType: 'Group'
  }
}


resource devopsSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(devopsSpnObjectId)) {
  name: guid(keyVault.id, devopsSpnObjectId, kvSecretsOfficerRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsOfficerRoleId)
    principalId: devopsSpnObjectId
    principalType: 'ServicePrincipal'
  }
}


output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
