# Dapr Pub/Sub Demo (.NET 8)

This demo shows two containerized .NET microservices (ProductService and OrderService) communicating via Dapr pub/sub using a Redis broker.

Note: Swagger/OpenAPI middleware was intentionally removed to keep the sample minimal and fast. To re-enable, add back `AddEndpointsApiExplorer()` and `AddSwaggerGen()` in each `Program.cs` and call `app.UseSwagger(); app.UseSwaggerUI();` in Development.

## Services
- ProductService: Publishes `product.created` events when a product is created (POST /products)
- OrderService: Subscribes to `product.created` events and auto-creates an order.

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
This provisions: Resource Group, Log Analytics, Container Apps Environment, ACR, Azure Cache for Redis, Dapr pub/sub component, and deploys both services.

### GitHub Actions Deploy
The workflow `.github/workflows/deploy.yml` deploys on pushes to `main`.

### Accessing Services (after deploy)
`azd show env` or check workflow logs for `productserviceUrl` and `orderserviceUrl`.

Create a product (replace PRODUCT_URL):
```
curl -X POST https://<PRODUCT_URL>/products -H 'Content-Type: application/json' -d '{"name":"Keyboard","price":55.5}'
```
List orders (replace ORDER_URL):
```
curl https://<ORDER_URL>/orders
```

### Notes
- ACR admin user enabled for simplicity; for production switch to managed identity + ACR Pull role.
- Dapr pub/sub component uses Redis with TLS (port 6380).
- Images are tagged per azd environment and pushed automatically.

