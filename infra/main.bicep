@description('Location for all resources')
param location string = resourceGroup().location
@description('Environment name (injected by azd)')
param azdEnvName string

// Images handled by azd separately; no direct reference needed here.

@description('Redis SKU (Basic, Standard, Premium)')
param redisSku string = 'Basic'
@description('Redis Capacity (0 = C0)')
param redisCapacity int = 0

var namePrefix = toLower(replace(azdEnvName, '_', '-'))
var acrName = take(replace('${namePrefix}acr','-',''), 50)
var workspaceName = '${namePrefix}-law'
var envName = '${namePrefix}-cae'
var redisName = replace('${namePrefix}-redis','_','-')

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 2
    }
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

resource managedEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: listKeys(logAnalytics.id, '2022-10-01').primarySharedKey
      }
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: redisName
  location: location
  sku: {
    name: redisSku
    family: 'C'
    capacity: redisCapacity
  }
  properties: {
    enableNonSslPort: false
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

resource pubsub 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = {
  name: 'messagebus'
  parent: managedEnv
  properties: {
    componentType: 'pubsub.redis'
    version: 'v1'
    metadata: [
      {
        name: 'redisHost'
        value: '${redis.name}.redis.cache.windows.net:6380'
      }
      {
        name: 'redisPassword'
        secretRef: 'redisPassword'
      }
      {
        name: 'enableTLS'
        value: 'true'
      }
    ]
    scopes: [
      'productservice'
      'orderservice'
    ]
    secrets: [
      {
  name: 'redisPassword'
  // NOTE: listKeys used due to lack of direct reference; acceptable for demo
  value: listKeys(redis.id, '2023-08-01').primaryKey
      }
    ]
  }
}

output containerRegistry string = acr.properties.loginServer
output daprPubSubName string = pubsub.name
