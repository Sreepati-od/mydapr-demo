# Dapr Pub/Sub Demo (.NET 8)

This demo shows two containerized .NET microservices (ProductService and OrderService) communicating via Dapr pub/sub.

Local: Redis component (for easy inspection / durability in dev).

Azure: Azure Service Bus (Standard) Dapr pub/sub component for durable event delivery (previous in-memory component replaced).

A lightweight React/Vite WebClient provides a simple UI.

Note: Swagger/OpenAPI middleware was intentionally removed to keep the sample minimal and fast. To re-enable, add back `AddEndpointsApiExplorer()` and `AddSwaggerGen()` in each `Program.cs` and call `app.UseSwagger(); app.UseSwaggerUI();` in Development.

## Services
- ProductService: Publishes `product.created` events when a product is created (POST /products)
- OrderService: Subscribes to `product.created` events and auto-creates an order.
- WebClient: React UI to create products and view orders.

## Prerequisites
- Docker & Docker Compose
- .NET 8 SDK
- Dapr CLI installed (`brew install dapr/tap/dapr-cli`)

## Run with Docker Compose

```
docker compose build
docker compose up
```

## Manual Local (without compose)
From root run in separate terminals:

```
# Run Redis (if not already):
docker run -d --name redis -p 6379:6379 redis:7-alpine

# ProductService
cd ProductService
 dotnet run
# Sidecar
 dapr run --app-id productservice --app-port 5183 --resources-path ../components -- dotnet run

# OrderService
cd ../OrderService
 dotnet run
# Sidecar
 dapr run --app-id orderservice --app-port 5215 --resources-path ../components -- dotnet run
```

## Test Flow
Host port mappings (container -> host):
- ProductService: 8080 -> 5001
- OrderService: 8080 -> 5002

1. Create product:
```
curl -X POST http://localhost:5001/products \
  -H 'Content-Type: application/json' \
  -d '{"name":"Keyboard","price":55.5}'
```
2. List orders (should contain auto-created order):
```
curl http://localhost:5002/orders
```

## Dapr HTTP Endpoints Useful for Debugging
```
# Subscriptions
curl http://localhost:3501/v1.0/subscribe

# Health
curl http://localhost:3500/v1.0/healthz
```

## Clean Up
```
docker compose down -v
```

## Azure Deployment (Container Apps + Dapr)

### Prerequisites
- Azure subscription
- Azure CLI (`az`) and Azure Dev CLI (`azd`) installed locally OR rely on GitHub Actions workflow.
- Create a Federated Credential / Service Principal for GitHub OIDC and add repository secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

### One-Time Local Bootstrap (optional)
```
azd auth login
azd env new dev --location eastus
azd up
```
This provisions: Resource Group, Container Apps Environment, ACR, Azure Service Bus namespace + Dapr pub/sub component, and deploys all three services.

### GitHub Actions Deploy
The workflow `.github/workflows/deploy.yml` deploys on pushes to `main`.

### Accessing Services (after deploy)
`azd show env` or check workflow logs for `webclientUrl`, `productserviceUrl`, and `orderserviceUrl`.

Open the WebClient URL in a browser, create a product, then watch the Orders list populate after the pub/sub event.

Create a product (replace PRODUCT_URL):
```
curl -X POST https://<PRODUCT_URL>/products -H 'Content-Type: application/json' -d '{"name":"Keyboard","price":55.5}'
```
List orders (replace ORDER_URL):
```
curl https://<ORDER_URL>/orders
```

### Remote Smoke Test
After deployment you can validate end-to-end propagation:

```
./tests/remote-smoke.sh https://<productservice_fqdn> https://<orderservice_fqdn>
```

Output should show an order referencing the created product ID within a few polling attempts.

### Notes
- ACR admin user enabled for simplicity; for production prefer managed identity + AcrPull.
- Azure Service Bus (Standard) selected for durability; you can downgrade to Basic if you only need queues or switch to another broker supported by Dapr.
- Images are tagged per azd environment and pushed automatically.
- The GitHub Actions workflow runs `azd up` and (TODO) could run the remote smoke test script as a post-deploy verification.

### Export Deliverables to Word (.docx)
Run the helper script (requires `pandoc` or Docker):
```
./scripts/export-deliverables.sh
```
Outputs `DELIVERABLES.docx` alongside the markdown.

// trigger deploy
