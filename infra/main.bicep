@description('Location for all resources')
param location string = resourceGroup().location
@description('Environment name (injected by azd)')
param azdEnvName string


var prefix = toLower(replace(azdEnvName,'_','-'))
var envName = '${prefix}-cae'
var logAnalyticsName = '${prefix}-logs'
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
// Log Analytics workspace for container app logs
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 2
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

// Container Apps Managed Environment (connected to Log Analytics)
resource managedEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspace.properties.customerId
        sharedKey: listKeys(logWorkspace.id, '2020-08-01').primarySharedKey
      }
    }
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

// Application Insights (workspace-based)
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-appi'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
    Flow_Type: 'Redfield'
    SamplingPercentage: 100
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}


// Azure Service Bus namespace for durable pub/sub
resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: '${prefix}sb${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  tags: {
    'azd-env-name': azdEnvName
  }
}

// Diagnostic settings for Service Bus -> Log Analytics
resource serviceBusDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sb-to-logs'
  scope: serviceBus
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'OperationalLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Dapr component (Azure Service Bus)
resource pubsub 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = {
  name: 'messagebus'
  parent: managedEnv
  properties: {
    componentType: 'pubsub.azure.servicebus'
    version: 'v1'
    metadata: [
      {
        name: 'connectionString'
        secretRef: 'servicebus-conn'
      }
    ]
    scopes: [
      'productservice'
      'orderservice'
    ]
    secrets: [
      {
        name: 'servicebus-conn'
        value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/AuthorizationRules', serviceBus.name, 'RootManageSharedAccessKey'), '2017-04-01').primaryConnectionString
      }
    ]
  }
}

// Reintroduced minimal Container Apps (azd will patch images on deploy)
resource productApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'productservice'
  location: location
  tags: {
    'azd-env-name': azdEnvName
    'azd-service-name': 'productservice'
  }
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
        {
          name: 'acr-pwd'
          value: acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-pwd'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'productservice'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        }
      ]
    }
  }
}

resource orderApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'orderservice'
  location: location
  tags: {
    'azd-env-name': azdEnvName
    'azd-service-name': 'orderservice'
  }
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
          name: 'acr-pwd'
          value: acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-pwd'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'orderservice'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        }
      ]
    }
  }
}

resource webclientApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'webclient'
  location: location
  tags: {
    'azd-env-name': azdEnvName
    'azd-service-name': 'webclient'
  }
  properties: {
    environmentId: managedEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      secrets: [
        {
          name: 'acr-pwd'
          value: acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: acr.properties.loginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-pwd'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'webclient'
          image: 'nginx:1.27-alpine'
        }
      ]
    }
  }
}


output containerRegistry string = acr.properties.loginServer
output daprPubSubName string = pubsub.name
output productserviceUrl string = productApp.properties.configuration.ingress.fqdn
output orderserviceUrl string = orderApp.properties.configuration.ingress.fqdn
output webclientUrl string = webclientApp.properties.configuration.ingress.fqdn
output logAnalyticsWorkspaceId string = logWorkspace.id
output applicationInsightsConnectionString string = appInsights.properties.ConnectionString
