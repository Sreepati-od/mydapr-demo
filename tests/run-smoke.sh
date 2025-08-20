#!/usr/bin/env bash
set -euo pipefail

# Smoke test for MyDaprDemo
# 1. Ensure docker compose stack is up
# 2. POST a product to ProductService (port 5001)
# 3. Poll OrderService (port 5002) until an order with matching productId appears
# 4. Report success/failure

PRODUCT_PORT=5001
ORDER_PORT=5002
TIMEOUT_SEC=30
POLL_INTERVAL=1

log() { printf "[%s] %s\n" "$(date -u +%H:%M:%S)" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }

need_cmd curl

if ! docker ps --format '{{.Names}}' | grep -q '^productservice$'; then
  log "Bringing up docker compose stack..."
  docker compose up -d --build
fi

wait_for_http() {
  local url=$1
  local waited=0
  until curl -fsS "$url" >/dev/null 2>&1; do
    sleep 1
    waited=$((waited+1))
    if [ $waited -ge $TIMEOUT_SEC ]; then
      log "Timeout waiting for $url"
      return 1
    fi
  done
  return 0
}

log "Waiting for ProductService on :$PRODUCT_PORT" && wait_for_http "http://localhost:$PRODUCT_PORT/products" || true
log "Waiting for OrderService on :$ORDER_PORT" && wait_for_http "http://localhost:$ORDER_PORT/orders" || true

# Create product
NAME="SmokeItem-$RANDOM"
PRICE="$(awk 'BEGIN{srand(); printf "%.2f", (rand()*90)+1 }')"
PRODUCT_JSON=$(curl -s -X POST "http://localhost:$PRODUCT_PORT/products" -H 'Content-Type: application/json' -d "{\"name\":\"$NAME\",\"price\":$PRICE}")
if [ -z "$PRODUCT_JSON" ]; then
  log "Failed to create product (empty response)"; exit 1
fi

if command -v jq >/dev/null 2>&1; then
  PRODUCT_ID=$(echo "$PRODUCT_JSON" | jq -r '.id')
else
  PRODUCT_ID=$(echo "$PRODUCT_JSON" | sed -n 's/.*"id":"\([a-f0-9-]\{36\}\)".*/\1/p')
fi

if [[ ! $PRODUCT_ID =~ ^[0-9a-fA-F-]{36}$ ]]; then
  log "Could not extract product id from response: $PRODUCT_JSON"; exit 1
fi
log "Created product $PRODUCT_ID ($NAME @ $PRICE)";

# Poll for order
log "Polling for matching order..."
MATCHED=false
START_TS=$(date +%s)
while true; do
  ORDERS_JSON=$(curl -s "http://localhost:$ORDER_PORT/orders") || ORDERS_JSON=""
  if echo "$ORDERS_JSON" | grep -q "$PRODUCT_ID"; then
    MATCHED=true
    break
  fi
  NOW=$(date +%s)
  ELAPSED=$((NOW-START_TS))
  if [ $ELAPSED -ge $TIMEOUT_SEC ]; then
    break
  fi
  sleep $POLL_INTERVAL
done

if [ "$MATCHED" = true ]; then
  log "SUCCESS: Order referencing product $PRODUCT_ID detected.";
  echo "$ORDERS_JSON" | (command -v jq >/dev/null 2>&1 && jq '.' || cat)
  exit 0
else
  log "FAIL: No order referencing product $PRODUCT_ID within ${TIMEOUT_SEC}s.";
  echo "Last orders payload:"; echo "$ORDERS_JSON" | (command -v jq >/dev/null 2>&1 && jq '.' || cat)
  exit 2
fi
