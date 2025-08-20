# Deployment Deliverables

Generated: 2025-08-20
Environment: `dev` (eastus)
Resource Group: `mydapr-demo-rg`
Subscription: 218e1f0d-74ff-455a-80a0-42cbbf8b4beb

---
## 1. Source Code Folder
Root repository contains:
- `ProductService/` (.NET 8 minimal API publishing `product.created`)
- `OrderService/` (.NET 8 minimal API subscribing to `product.created` via Dapr controller)
- `WebClient/` (React + Vite + TypeScript UI)
- `infra/` (Bicep templates including ACR, Container Apps Env, Service Bus, Dapr component, monitoring)
- `components/` (local dev Dapr component definitions e.g., Redis)
- `tests/` (local and remote smoke test scripts)
- `scripts/` (OIDC setup automation)
- `.github/workflows/` (CI/CD workflow `deploy.yml`)

## 2. Dockerfiles
- `ProductService/Dockerfile` (multi-stage build/publish for .NET service)
- `OrderService/Dockerfile`
- `WebClient/Dockerfile` (multi-stage Node build to Nginx static image)

## 3. Container Image Details
Registry: `devacr5cktvb.azurecr.io`
Images (latest deployed tags):
- ProductService: `devacr5cktvb.azurecr.io/mydapr-demo/productservice-dev:azd-deploy-1755697391`
- OrderService: `devacr5cktvb.azurecr.io/mydapr-demo/orderservice-dev:azd-deploy-1755697362`
- WebClient: `devacr5cktvb.azurecr.io/mydapr-demo/webclient-dev:azd-deploy-1755697417`

## 4. Dapr Components Configuration
Azure (Service Bus) component (Bicep excerpt):
```
resource pubsub 'Microsoft.App/managedEnvironments/daprComponents@2024-03-01' = {
  name: 'messagebus'
  parent: managedEnv
  properties: {
    componentType: 'pubsub.azure.servicebus'
    version: 'v1'
    metadata: [{ name: 'connectionString' secretRef: 'servicebus-conn' }]
    scopes: ['productservice','orderservice']
    secrets: [{ name: 'servicebus-conn' value: <resolved at deploy> }]
  }
}
```
Local development uses `components/pubsub.yaml` (Redis) for the same `pubsub` name.

## 5. Azure Deployment Config
Key files/resources:
- `azure.yaml` (maps services to Container Apps host, registry var)
- `infra/main.bicep` (ACR, Managed Environment, Container Apps, Service Bus, Dapr component, Log Analytics, App Insights, diagnostics)
- GitHub Action: `.github/workflows/deploy.yml` (OIDC auth + `azd up` + remote smoke test)
- OIDC setup script: `scripts/azure-oidc-setup.sh`

Outputs:
- Container Apps:
  - ProductService FQDN: `productservice.greenwave-c17ce43f.eastus.azurecontainerapps.io`
  - OrderService FQDN: `orderservice.greenwave-c17ce43f.eastus.azurecontainerapps.io`
  - WebClient FQDN: `webclient.greenwave-c17ce43f.eastus.azurecontainerapps.io`
- Dapr PubSub Name: `messagebus`
- Log Analytics Workspace Id: `/subscriptions/.../workspaces/dev-logs`
- App Insights Connection String: (see env values)

## 6. Architecture Diagram
```
                 +----------------------+
                 |   WebClient (Nginx)  |
                 |  React/Vite Frontend |
                 +-----------+----------+
                             |
                             | HTTP (create product / list orders)
                             v
+------------------+    Dapr Sidecar    +------------------+
| ProductService   |<------------------>| OrderService     |
| .NET 8 API       |    Pub/Sub Topic   | .NET 8 API       |
| POST /products   |  "product.created" | GET /orders      |
+---------+--------+                    +---------+--------+
          | Publish (messagebus)                  ^
          v                                       |
      +----------------------------- Azure Service Bus -----------------------------+
      |  Namespace (Standard)  |  Dapr Component: pubsub.azure.servicebus            |
      +------------------------+----------------------------------------------------+
                             |
                             v (Logs, Metrics)
        +------------------+        +----------------------+
        | Log Analytics    |<------>| Container Apps Env   |
        +------------------+        +----------------------+
                 ^                             |
                 | Workspace-based             |
                 | telemetry                   v
                 |                   +----------------------+
                 |                   | App Insights (web)   |
                 |                   +----------------------+

        +------------------+
        | Azure Container  |
        | Registry (ACR)   |
        +------------------+
```

## 7. Screenshots and Logs (Representative Text Evidence)
Deployment success (excerpt):
```
SUCCESS: Your application was deployed to Azure ...
Endpoint: https://productservice.../ 
Endpoint: https://orderservice.../
Endpoint: https://webclient.../
```
Remote smoke test (successful propagation):
```
[INFO] Create response: {"id":"923567d8-5532-45dc-9749-25ed83282638",...}
[PASS] Order referencing product 923567d8-5532-45dc-9749-25ed83282638 observed.
```
Provision with monitoring (excerpt):
```
Done: Log Analytics workspace: dev-logs
Done: Application Insights: dev-appi
```

## 8. README.md
See `README.md` in repository root for detailed usage, local run, and deployment instructions.

---
## Verification Summary
- Source code present & structured.
- Docker images built and deployed; FQDNs reachable.
- Durable pub/sub via Azure Service Bus verified by remote smoke test.
- Monitoring enabled: Log Analytics + App Insights.
- CI/CD workflow operational with OIDC.

## Follow-Up Recommendations
1. Add alerts (failed requests, 5xx rate) via Azure Monitor.
2. Enforce managed identity for ACR pulls (disable admin user).
3. Add Kusto queries directory with saved queries.
4. Consider autoscaling rules for Container Apps (CPU/RPS).

---
End of Deliverables.
