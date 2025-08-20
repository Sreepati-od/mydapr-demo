@description('Location for all resources')
param location string = resourceGroup().location
@description('Environment name (injected by azd)')
param azdEnvName string


var prefix = toLower(replace(azdEnvName,'_','-'))
var envName = '${prefix}-cae'
// Construct a globally unique ACR name (5-50 lowercase alphanumerics)
var acrBase = toLower(replace('${prefix}acr','-',''))
var acrSuffix = toLower(substring(uniqueString(resourceGroup().id, 'acr'),0,6))
var acrRaw = '${acrBase}${acrSuffix}'
var acrName = substring(acrRaw, 0, min(length(acrRaw),50))

// ACR
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

// Managed Environment (no log analytics to simplify)
resource managedEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {}
  tags: {
    'azd-env-name': azdEnvName
  }
}


// Dapr component
resource pubsub 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = {
  name: 'messagebus'
  parent: managedEnv
  properties: {
  componentType: 'pubsub.in-memory'
    version: 'v1'
  metadata: []
    scopes: [
      'productservice'
      'orderservice'
    ]
  secrets: []
  }
}


output containerRegistry string = acr.properties.loginServer
output daprPubSubName string = pubsub.name
