param prefix string
param location string
param environment string

var isProd = environment == 'prod'
var isTest = environment == 'test'

var vnetAddressPrefix = (environment == 'dev') ? '10.2.0.0/16' : (environment == 'test') ? '10.3.0.0/16' : '10.1.0.0/16'


resource nsgDb 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-${prefix}-db'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-sql-from-functions'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: cidrSubnet(vnetAddressPrefix, 24, 2)
          destinationPortRange: '1433'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'allow-sql-from-logicapp'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: cidrSubnet(vnetAddressPrefix, 24, 3)
          destinationPortRange: '1433'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'deny-all-inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgFunctions 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: 'nsg-${prefix}-functions'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-https-outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'vnet-${prefix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: 'subnet-storage'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 0)
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-db'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 1)
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: {
            id: nsgDb.id
          }
        }
      }
      {
        name: 'subnet-functions'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 2)
          networkSecurityGroup: {
            id: nsgFunctions.id
          }
          delegations: [
            {
              name: 'delegation-functions'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
      {
        name: 'subnet-logicapp'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 3)
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-ai'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 4)
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-vm'
        properties: {
          addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 5)
        }
      }
    ]
  }
}


resource dnsZoneSql 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
}

resource dnsZoneSqlLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneSql
  name: 'link-sql-${prefix}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}


resource dnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

resource dnsZoneBlobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneBlob
  name: 'link-blob-${prefix}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}


resource dnsZoneKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

resource dnsZoneKvLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZoneKv
  name: 'link-kv-${prefix}'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnet.id }
    registrationEnabled: false
  }
}


output vnetId string = vnet.id
output vnetName string = vnet.name
output storageSubnetId string = '${vnet.id}/subnets/subnet-storage'
output dbSubnetId string = '${vnet.id}/subnets/subnet-db'
output functionsSubnetId string = '${vnet.id}/subnets/subnet-functions'
output logicappSubnetId string = '${vnet.id}/subnets/subnet-logicapp'
output aiSubnetId string = '${vnet.id}/subnets/subnet-ai'
output vmSubnetId string = '${vnet.id}/subnets/subnet-vm'
output dnsZoneSqlId string = dnsZoneSql.id
output dnsZoneBlobId string = dnsZoneBlob.id
output dnsZoneKvId string = dnsZoneKv.id
