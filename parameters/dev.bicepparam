using '../main.bicep'

param environment = 'dev'
param location = 'westeurope'
param sqlAdminLogin = 'sqladmin'

param developerGroupObjectId = ''
param qaGroupObjectId = ''
param businessUserGroupObjectId = ''
param devopsSpnObjectId = ''
