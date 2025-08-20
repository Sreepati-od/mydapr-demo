@description('Location for all resources')
param location string = resourceGroup().location
@description('Environment name (injected by azd)')
param azdEnvName string

@description('Product service container image')
param productserviceImage string
@description('Order service container image')
param orderserviceImage string
@description('Web client container image')
param webclientImage string

var prefix = toLower(replace(azdEnvName,'_','-'))
var envName = '${prefix}-cae'
var acrRaw = replace('${prefix}acr','-','')
var acrName = length(acrRaw) < 5 ? '${acrRaw}00000' : substring(acrRaw,0, min(length(acrRaw),50))

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

// Product Container App
resource productApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'productservice'
  location: location
  properties: {
    environmentId: managedEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      dapr: {
        appId: 'productservice'
        appPort: 8080
        enabled: true
      }
      secrets: [
        // ACR credentials looked up dynamically at deploy time (warnings ignored for demo)
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'productservice'
          image: productserviceImage
        }
      ]
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

// Order Container App
resource orderApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'orderservice'
  location: location
  properties: {
    environmentId: managedEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      dapr: {
        appId: 'orderservice'
        appPort: 8080
        enabled: true
      }
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'orderservice'
          image: orderserviceImage
        }
      ]
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

// Web Client Container App (static front-end)
resource webclientApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'webclient'
  location: location
  properties: {
    environmentId: managedEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'webclient'
          image: webclientImage
          // Optionally add env vars if we later implement runtime substitution
        }
      ]
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

output productserviceUrl string = productApp.properties.configuration.ingress.fqdn
output orderserviceUrl string = orderApp.properties.configuration.ingress.fqdn
output webclientUrl string = webclientApp.properties.configuration.ingress.fqdn
output containerRegistry string = acr.properties.loginServer
output daprPubSubName string = pubsub.name
