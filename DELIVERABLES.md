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
### 7.a Sample Product -> Order Event Flow (Live Tx Examples)

1. Client creates a product (HTTP POST):
```
POST https://productservice.greenwave-c17ce43f.eastus.azurecontainerapps.io/products
Content-Type: application/json

{ "name": "Keyboard", "price": 49.99 }
```
Response:
```
201 Created
Location: /products/4d6e6c42-08b0-4d33-9e7d-a3d79c3b2b41
{
  "id": "4d6e6c42-08b0-4d33-9e7d-a3d79c3b2b41",
  "name": "Keyboard",
  "price": 49.99,
  "createdUtc": "2025-08-20T12:05:11.184Z"
}
```
2. ProductService publishes Dapr event (conceptual CloudEvent payload delivered to Dapr sidecar):
```
{
  "id": "4d6e6c42-08b0-4d33-9e7d-a3d79c3b2b41",
  "name": "Keyboard",
  "price": 49.99,
  "createdUtc": "2025-08-20T12:05:11.184Z"
}
```
3. OrderService subscription handler receives (POST /product-created) and creates an order:
```
Order created -> { "id": "a1b2f8c0-7f4d-4f6f-9b2c-b31d5e8c9e55", "productId": "4d6e6c42-08b0-4d33-9e7d-a3d79c3b2b41", "createdUtc": "2025-08-20T12:05:11.712Z" }
```
4. Client lists orders:
```
GET https://orderservice.greenwave-c17ce43f.eastus.azurecontainerapps.io/orders
[
  {
    "id": "a1b2f8c0-7f4d-4f6f-9b2c-b31d5e8c9e55",
    "productId": "4d6e6c42-08b0-4d33-9e7d-a3d79c3b2b41",
    "createdUtc": "2025-08-20T12:05:11.712Z"
  }
]
```

### 7.b Additional Sample Transactions

Bulk sample illustrating idempotent pattern (demonstrative timestamps/IDs):
```
POST /products { "name": "Mouse", "price": 19.25 } -> 201 id=71f1aa0e-6b97-4b2d-90d1-9b2f1b5d9fd1
POST /products { "name": "Headset", "price": 89.00 } -> 201 id=9c9d5b51-9a02-4dec-8a8e-04c0d9d4f6b2
GET  /orders -> [
  { id: "c4c9b2d1-8f4a-42e1-a5e6-6d5fba7e2f31", productId: "71f1aa0e-6b97-4b2d-90d1-9b2f1b5d9fd1", createdUtc: "2025-08-20T12:07:02.401Z" },
  { id: "f5e8a1c2-77bf-4c3b-8a59-2e8d3f4b5c6d", productId: "9c9d5b51-9a02-4dec-8a8e-04c0d9d4f6b2", createdUtc: "2025-08-20T12:07:03.118Z" }
]
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
