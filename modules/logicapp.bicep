param prefix string
param location string
param storageAccountName string
param storageAccountKey string
param containerName string
param functionAppUrl string
param keyVaultName string


resource blobApiConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: 'conn-blob-${prefix}'
  location: location
  properties: {
    displayName: 'MovePay Storage Connection (${prefix})'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    }
    parameterValues: {
      accountName: storageAccountName
      accessKey: storageAccountKey
    }
  }
}


resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'logic-${prefix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        When_a_blob_is_added_or_modified: {
          recurrence: {
            frequency: 'Minute'
            interval: 1
          }
          evaluatedRecurrence: {
            frequency: 'Minute'
            interval: 1
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'${storageAccountName}\'))}/triggers/batch/onupdatedfile'
            queries: {
              checkBothCreatedAndModifiedDateTime: false
              folderId: containerName
              maxFileCount: 10
            }
          }
        }
      }
      actions: {
        Get_function_key_from_KeyVault: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: 'https://${keyVaultName}.vault.azure.net/secrets/function-key-payment-processor?api-version=7.4'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://vault.azure.net'
            }
          }
        }
        Parse_function_key: {
          type: 'ParseJson'
          runAfter: {
            Get_function_key_from_KeyVault: ['Succeeded']
          }
          inputs: {
            content: '@body(\'Get_function_key_from_KeyVault\')'
            schema: {
              type: 'object'
              properties: {
                value: { type: 'string' }
              }
            }
          }
        }
        Call_payment_processor: {
          type: 'Http'
          runAfter: {
            Parse_function_key: ['Succeeded']
          }
          inputs: {
            method: 'POST'
            uri: '${functionAppUrl}/api/payment_processor'
            queries: {
              code: '@body(\'Parse_function_key\')[\'value\']'
            }
            body: {
              blobName: '@triggerBody()?[\'Name\']'
              blobPath: '@triggerBody()?[\'Path\']'
              storageAccount: storageAccountName
              container: containerName
              environment: prefix
            }
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          azureblob: {
            connectionId: blobApiConnection.id
            connectionName: blobApiConnection.name
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
          }
        }
      }
    }
  }
}


output logicAppId string = logicApp.id
output logicAppName string = logicApp.name
output logicAppPrincipalId string = logicApp.identity.principalId
