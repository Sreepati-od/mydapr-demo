#!/usr/bin/env sh
set -eu
# Generate runtime config file from env vars (if provided)
: ${PRODUCTS_API_URL:=}
: ${ORDERS_API_URL:=}
CONFIG_FILE=/usr/share/nginx/html/config.json
cat > $CONFIG_FILE <<EOF
{
  "productsApiUrl": "${PRODUCTS_API_URL}",
  "ordersApiUrl": "${ORDERS_API_URL}"
}
EOF
exec nginx -g 'daemon off;'
