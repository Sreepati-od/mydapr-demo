# Architecture Overview

## Purpose
Minimal demo showcasing event-driven microservices with Dapr pub/sub on Azure Container Apps plus a lightweight React web client.

## Components
- ProductService (.NET 8 minimal API) publishes `product.created` events to Dapr component `messagebus` (Azure Service Bus)
- OrderService (.NET 8 minimal API + Dapr subscription) consumes `product.created` and creates in-memory orders
- WebClient (React + Vite + Nginx) fetches product & order lists and allows creation of new products / manual orders
- Dapr Component: `pubsub.azure.servicebus` defined at environment scope
- Azure Infrastructure (Bicep): Container Apps Environment, ACR, Service Bus, Log Analytics, Application Insights

## Event Flow
1. Client POST /products (ProductService)
2. ProductService publishes CloudEvent `product.created`
3. Dapr routes event via Service Bus to OrderService subscription
4. OrderService creates order entry linked to product Id
5. Client polls /orders or refreshes to view new order

## Runtime Config
WebClient container injects `PRODUCTS_API_URL` and `ORDERS_API_URL` -> entrypoint script writes `config.json` -> frontend loads dynamically (avoids rebuild for endpoint changes).

## CORS
Current default `*` for demo. Set `ALLOWED_ORIGINS` env variable on each service to restrict in production (`https://<webclient-fqdn>`).

## Observability
- Application Insights (workspace-based) for distributed telemetry
- Log Analytics workspace for container & Service Bus diagnostics

## Security Notes
- GitHub OIDC used for CI/CD (see `scripts/azure-oidc-setup.sh`)
- No secrets in repo; Service Bus connection wired via Dapr component secret.

## Persistence
In-memory only (demo). For durability introduce a state store (e.g., Azure Cosmos DB or Azure Table Storage) via additional Dapr components.

## Future Hardening (Optional)
- Replace wildcard CORS
- Add structured logging (Serilog or built-in logging abstractions)
- Add persistence + retry policies
- Remove admin ACR user (switch to managed identity)

