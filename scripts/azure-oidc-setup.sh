#!/usr/bin/env bash
set -euo pipefail

# Purpose: One-shot setup for Azure AD App + OIDC federated credential + role assignments + GitHub secrets.
# Safe to re-run (idempotent where practical).

#############################
# CONFIGURABLE VARIABLES
#############################
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"          # Required (export beforehand or fill value)
LOCATION="${LOCATION:-eastus}"                  # Azure region for resource group if created
RESOURCE_GROUP="${RESOURCE_GROUP:-mydapr-demo-rg}"  # RG to scope role assignments
ENV_NAME="${ENV_NAME:-dev}"                    # azd environment name (informational)
APP_NAME="${APP_NAME:-mydapr-demo-oidc}"       # Azure AD App display name
REPO_OWNER="${REPO_OWNER:-Sreepati-od}"        # GitHub org / user
REPO_NAME="${REPO_NAME:-mydapr-demo}"          # Repository name
BRANCH_REF="${BRANCH_REF:-refs/heads/main}"    # Branch reference for federated credential
FED_NAME="${FED_NAME:-gh-main}"                # Federated credential name
USE_CONTRIBUTOR="${USE_CONTRIBUTOR:-false}"    # If true, assign broad Contributor instead of granular roles

# Granular roles (least-privilege set). Adjust as needed.
GRANULAR_ROLES=(
  "Container App Contributor"  # manage Container Apps
  "AcrPush"                    # push/pull images
  "Monitoring Reader"          # read logs/metrics
)

#############################
# PRECHECKS
#############################
command -v az >/dev/null || { echo "Azure CLI (az) not found" >&2; exit 1; }
command -v gh >/dev/null || { echo "GitHub CLI (gh) not found" >&2; exit 1; }

# Ensure Azure login
if ! az account show >/dev/null 2>&1; then
  echo "[INFO] Not logged into Azure. Starting device login..."
  az login --use-device-code >/dev/null
fi

# Ensure GitHub CLI login (repo scope needed for secrets)
if ! gh auth status -h github.com >/dev/null 2>&1; then
  echo "[INFO] GitHub CLI not authenticated. Launching interactive login..."
  gh auth login -h github.com
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "ERROR: SUBSCRIPTION_ID not set. Export SUBSCRIPTION_ID=<id> then rerun." >&2
  exit 1
fi

echo "[INFO] Setting subscription $SUBSCRIPTION_ID ..."
az account set --subscription "$SUBSCRIPTION_ID"

TENANT_ID=$(az account show --query tenantId -o tsv)
echo "[INFO] Tenant: $TENANT_ID"

#############################
# RESOURCE GROUP (optional)
#############################
if ! az group show -n "$RESOURCE_GROUP" &>/dev/null; then
  echo "[INFO] Creating resource group $RESOURCE_GROUP in $LOCATION"
  az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --tags azd-env-name="$ENV_NAME" >/dev/null
else
  echo "[INFO] Resource group $RESOURCE_GROUP exists"
fi

#############################
# APP REGISTRATION
#############################
EXISTING_APP_ID=$(az ad app list --display-name "$APP_NAME" --query '[0].appId' -o tsv || true)
if [[ -z "$EXISTING_APP_ID" || "$EXISTING_APP_ID" == "null" ]]; then
  echo "[INFO] Creating app registration $APP_NAME"
  CLIENT_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
else
  echo "[INFO] Reusing existing app registration $APP_NAME"
  CLIENT_ID="$EXISTING_APP_ID"
fi

# Ensure service principal exists
if ! az ad sp show --id "$CLIENT_ID" &>/dev/null; then
  echo "[INFO] Creating service principal for app"
  az ad sp create --id "$CLIENT_ID" >/dev/null
else
  echo "[INFO] Service principal already exists"
fi

SP_OBJECT_ID=$(az ad sp show --id "$CLIENT_ID" --query id -o tsv)

#############################
# FEDERATED CREDENTIAL
#############################
SUBJECT="repo:${REPO_OWNER}/${REPO_NAME}:ref:${BRANCH_REF}"
echo "[INFO] Ensuring federated credential ($FED_NAME -> $SUBJECT) exists"
EXISTS=$(az ad app federated-credential list --id "$CLIENT_ID" --query "[?name=='$FED_NAME'] | length(@)" -o tsv)
if [[ "$EXISTS" == "0" ]]; then
  TMP_JSON=$(mktemp)
  cat > "$TMP_JSON" <<JSON
{
  "name": "$FED_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "$SUBJECT",
  "audiences": ["api://AzureADTokenExchange"]
}
JSON
  az ad app federated-credential create --id "$CLIENT_ID" --parameters @"$TMP_JSON" >/dev/null
  rm -f "$TMP_JSON"
  echo "[INFO] Federated credential created"
else
  echo "[INFO] Federated credential already present"
fi

#############################
# ROLE ASSIGNMENTS
#############################
SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

assign_role() {
  local roleName="$1"
  if az role assignment list --assignee "$SP_OBJECT_ID" --scope "$SCOPE" --role "$roleName" --query "length(@)" -o tsv | grep -q '^0$'; then
    echo "[INFO] Assigning role: $roleName"
    az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
      --assignee-principal-type ServicePrincipal --role "$roleName" --scope "$SCOPE" >/dev/null || {
        echo "[WARN] Failed assigning $roleName (may not exist in your tenant).";
      }
  else
    echo "[INFO] Role $roleName already assigned"
  fi
}

if [[ "$USE_CONTRIBUTOR" == "true" ]]; then
  assign_role "Contributor"
else
  for r in "${GRANULAR_ROLES[@]}"; do assign_role "$r"; done
fi

#############################
# GITHUB SECRETS
#############################
if gh repo view "$REPO_OWNER/$REPO_NAME" &>/dev/null; then
  echo "[INFO] Setting GitHub repo secrets via gh CLI"
  gh secret set AZURE_CLIENT_ID -b"$CLIENT_ID" --repo "$REPO_OWNER/$REPO_NAME"
  gh secret set AZURE_TENANT_ID -b"$TENANT_ID" --repo "$REPO_OWNER/$REPO_NAME"
  gh secret set AZURE_SUBSCRIPTION_ID -b"$SUBSCRIPTION_ID" --repo "$REPO_OWNER/$REPO_NAME"
else
  echo "[WARN] Repository $REPO_OWNER/$REPO_NAME not accessible via gh; skipping secret creation."
fi

cat <<EOF
[SUCCESS] OIDC setup complete. Values:
 AZURE_CLIENT_ID=$CLIENT_ID
 AZURE_TENANT_ID=$TENANT_ID
 AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID

Security recommendations:
 - Keep roles granular (avoid full Contributor if not needed).
 - Pin GitHub Actions to commit SHAs.
 - Enable Dependabot alerts & automatic security updates.
 - Configure branch protection (PR reviews, status checks, optionally signed commits).
 - Periodically audit and prune federated credentials and app registrations.
 - Consider adding workload identity federation for other environments (e.g., staging).
EOF
