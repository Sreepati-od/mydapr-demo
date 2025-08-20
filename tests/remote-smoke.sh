#!/usr/bin/env bash
set -euo pipefail

# Remote smoke test against deployed Azure Container Apps.
# Usage: remote-smoke.sh <productservice_base_url> <orderservice_base_url>
# Example: remote-smoke.sh https://productservice.xxx.azurecontainerapps.io https://orderservice.xxx.azurecontainerapps.io

if [[ ${1:-} == "" || ${2:-} == "" ]]; then
  echo "Usage: $0 <productservice_base_url> <orderservice_base_url>" >&2
  exit 1
fi

PRODUCT_BASE=${1%/}
ORDER_BASE=${2%/}
TS=$(date +%s)
BODY=$(printf '{"name":"Cloud Widget %s","price":19.99}' "$TS")

echo "[INFO] Creating product: $BODY" >&2
HTTP_CODE=$(curl -s -o /tmp/create_body -w '%{http_code}' -H 'Content-Type: application/json' -d "$BODY" "$PRODUCT_BASE/products") || true
RESP=$(cat /tmp/create_body || true)
echo "[INFO] Create status: $HTTP_CODE" >&2
echo "[INFO] Create response: $RESP" >&2

if [[ "$HTTP_CODE" != "201" && "$HTTP_CODE" != "200" ]]; then
  echo "[FAIL] Product creation failed (status $HTTP_CODE)" >&2
  exit 2
fi

# Extract GUID id if present
PROD_ID=$(grep -Eo '"id"[^"]*"[0-9a-fA-F-]{36}"' /tmp/create_body | grep -Eo '[0-9a-fA-F-]{36}' | head -n1 || true)
echo "[INFO] Product ID: ${PROD_ID:-<not found>}" >&2

echo "[INFO] Polling orders for propagation (up to 30s)..." >&2
FOUND=0
for i in $(seq 1 10); do
  ORDERS_HTTP=$(curl -s -o /tmp/orders_body -w '%{http_code}' "$ORDER_BASE/orders" || true)
  ORDERS_BODY=$(cat /tmp/orders_body || true)
  echo "[DEBUG] Attempt $i status=$ORDERS_HTTP body=$ORDERS_BODY" >&2
  if [[ -n "$PROD_ID" && "$ORDERS_BODY" == *"$PROD_ID"* ]]; then
    FOUND=1
    break
  fi
  sleep 3
done

if [[ $FOUND -eq 1 ]]; then
  echo "[PASS] Order referencing product $PROD_ID observed."; exit 0
else
  echo "[WARN] Order not observed after polling window."; exit 3
fi
