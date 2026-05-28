#!/bin/bash
# =============================================================================
# deploy-poc-cloudshell.sh
#
# Run this inside Azure Cloud Shell — https://shell.azure.com
# Nothing to install on your laptop. Cloud Shell has az CLI, git, and
# az acr build (which builds your Docker image IN Azure — no local Docker).
#
# HOW TO USE:
#   1. Push your code to GitHub  (see POC_QUICKSTART.md Step 0)
#   2. Open https://shell.azure.com  in your browser
#   3. Clone your repo:   git clone https://github.com/<you>/<repo>.git
#   4. cd into the repo and run:   bash scripts/deploy-poc-cloudshell.sh
# =============================================================================

set -euo pipefail

# ── Config — change these if you want ────────────────────────────────────────
RESOURCE_GROUP="rg-product-catalog-poc"
ACR_NAME="acrproductcatalogpoc"          # fixed name — idempotent across retries
ACA_ENV="aca-env-poc"
IMAGE_NAME="product-catalog-service"
IMAGE_TAG="poc-$(git rev-parse --short HEAD 2>/dev/null || echo latest)"

# Tags for resource organization and cost tracking
TAGS="Project=product-catalog-poc Environment=poc Owner=shalini CostCenter=engineering"

echo ""
echo "================================================="
echo "  Product Catalog POC — Azure Cloud Shell Deploy"
echo "================================================="
echo "  Resource Group : $RESOURCE_GROUP"
echo "  ACR Name       : $ACR_NAME"
echo "================================================="
echo ""

# ── 1. Verify Resource Group Exists ───────────────────────────────────────────
echo ">>> [1/6] Checking resource group..."

RG_EXISTS=$(az group exists --name "$RESOURCE_GROUP" --output tsv)

if [ "$RG_EXISTS" != "true" ]; then
    echo "ERROR: Resource group '$RESOURCE_GROUP' does not exist."
    echo "       Please create it first or update RESOURCE_GROUP in this script."
    exit 1
fi

LOCATION=$(az group show --name "$RESOURCE_GROUP" --query "location" --output tsv)
echo "    Using existing resource group in: $LOCATION"

# ── 1b. Register required resource providers ──────────────────────────────────
echo ">>> [1b/6] Registering required Azure resource providers..."

register_provider() {
    local PROVIDER="$1"
    local STATE
    STATE=$(az provider show --namespace "$PROVIDER" --query "registrationState" --output tsv 2>/dev/null || echo "NotFound")

    if [ "$STATE" = "Registered" ]; then
        echo "    $PROVIDER already registered."
        return 0
    fi

    echo "    Registering $PROVIDER (this may take ~2 min)..."
    az provider register --namespace "$PROVIDER" 2>/dev/null || true

    # Poll until Registered or timeout (90 × 10s = 15 min max)
    local RETRIES=90
    for i in $(seq 1 $RETRIES); do
        STATE=$(az provider show --namespace "$PROVIDER" --query "registrationState" --output tsv 2>/dev/null || echo "Unknown")
        if [ "$STATE" = "Registered" ]; then
            echo "    $PROVIDER registered."
            return 0
        fi
        echo "    [$i/$RETRIES] $PROVIDER state: $STATE — waiting 10s..."
        sleep 10
    done

    echo ""
    echo "ERROR: $PROVIDER did not reach 'Registered' state after waiting."
    echo "       You may lack permission to register providers on this subscription."
    echo "       Ask your subscription Owner/Admin to run:"
    echo "         az provider register --namespace $PROVIDER"
    echo "       Then re-run this script."
    exit 1
}

for PROVIDER in Microsoft.ContainerRegistry Microsoft.App Microsoft.OperationalInsights; do
    register_provider "$PROVIDER"
done

# ── 2. Create Azure Container Registry (idempotent) ──────────────────────────
echo ">>> [2/6] Checking container registry: $ACR_NAME"
ACR_EXISTS=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" \
    --query "name" --output tsv 2>/dev/null || true)

if [ -n "$ACR_EXISTS" ]; then
    echo "    Registry already exists, reusing it."
else
    echo "    Creating registry..."
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name           "$ACR_NAME" \
        --sku            Basic \
        --admin-enabled  true \
        --tags           $TAGS Component=registry \
        --output         none
    echo "    Done."
fi

ACR_SERVER="${ACR_NAME}.azurecr.io"

# ── 3. Wait for image built by GitHub Actions ─────────────────────────────────
echo ">>> [3/6] Checking for Docker image in ACR..."
echo ""
echo "  ACR Tasks are blocked on this subscription."
echo "  The image must be pushed via GitHub Actions (already configured in"
echo "  .github/workflows/azure-deploy.yml)."
echo ""
echo "  ── GitHub Secrets required ─────────────────────────────────────────"

ACR_ADMIN_USER=$(az acr credential show --name "$ACR_NAME" --query "username" --output tsv)
ACR_ADMIN_PASS=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" --output tsv)

echo "  Add these at: https://github.com/<your-repo>/settings/secrets/actions"
echo ""
echo "    ACR_NAME              = $ACR_NAME"
echo "    AZURE_RESOURCE_GROUP  = $RESOURCE_GROUP"
echo "    AZURE_CREDENTIALS     = <service-principal JSON — see note below>"
echo ""
echo "  To create AZURE_CREDENTIALS:"
echo "    az ad sp create-for-rbac --name sp-product-catalog-poc \\"
echo "      --role contributor \\"
echo "      --scopes /subscriptions/\$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP \\"
echo "      --sdk-auth"
echo ""
echo "  ────────────────────────────────────────────────────────────────────"
echo "  Push your code to main to trigger the GitHub Actions build."
echo "  This script will wait up to 30 minutes for the image to appear."
echo "  Press Ctrl+C to exit and re-run this script after the image is ready."
echo ""

# Poll ACR for the image (every 20s, up to 30 min)
IMAGE_TAG_FOUND=""
for i in $(seq 1 90); do
    IMAGE_TAG_FOUND=$(az acr repository show-tags \
        --name "$ACR_NAME" \
        --repository "$IMAGE_NAME" \
        --orderby time_desc \
        --output tsv 2>/dev/null | head -1 || true)
    if [ -n "$IMAGE_TAG_FOUND" ]; then
        echo "    Image found: ${IMAGE_NAME}:${IMAGE_TAG_FOUND}"
        break
    fi
    echo "    [$i/90] Image not in ACR yet — waiting 20s..."
    sleep 20
done

if [ -z "$IMAGE_TAG_FOUND" ]; then
    echo "ERROR: Image '${IMAGE_NAME}' not found in ACR after 30 minutes."
    echo "       Trigger the GitHub Actions workflow and re-run this script."
    exit 1
fi

FULL_IMAGE="${ACR_SERVER}/${IMAGE_NAME}:${IMAGE_TAG_FOUND}"
echo "    Deploying image: $FULL_IMAGE"

# ── 4. Create Container Apps Environment ──────────────────────────────────────
echo ">>> [4/6] Creating Container Apps environment..."
az containerapp env create \
    --name           "$ACA_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location       "$LOCATION" \
    --tags           $TAGS \
    --output         none 2>/dev/null || echo "    (Environment may already exist, continuing...)"
echo "    Done."

# ── 5. Deploy the full stack ───────────────────────────────────────────────────
echo ">>> [5/6] Deploying full stack (postgres + couchbase + kafka + app)..."
echo "    Using: docker-compose.poc.yml"

# Export so the compose file can pick up ACR_IMAGE
export ACR_IMAGE="$FULL_IMAGE"

az containerapp compose create \
    --environment       "$ACA_ENV" \
    --resource-group    "$RESOURCE_GROUP" \
    --compose-file-path docker-compose.poc.yml \
    --output            none
echo "    Deployment submitted."

# ── 6. Get URL ────────────────────────────────────────────────────────────────
echo ">>> [6/6] Fetching application URL..."

APP_FQDN=$(az containerapp show \
    --name           "app" \
    --resource-group "$RESOURCE_GROUP" \
    --query          "properties.configuration.ingress.fqdn" \
    --output         tsv 2>/dev/null || true)

echo ""
echo "================================================="
echo "  DEPLOYMENT COMPLETE"
echo "================================================="
if [ -n "$APP_FQDN" ]; then
    echo "  App URL    : https://$APP_FQDN"
    echo "  Swagger UI : https://$APP_FQDN/swagger-ui/index.html"
    echo "  Health     : https://$APP_FQDN/actuator/health"
else
    echo "  Run this to get the URL once containers are ready:"
    echo "  az containerapp list --resource-group $RESOURCE_GROUP \\"
    echo "    --query \"[].properties.configuration.ingress.fqdn\" -o tsv"
fi
echo ""
echo "  ACR    : $ACR_SERVER"
echo "  Image  : $FULL_IMAGE"
echo ""
echo "  To stop billing when done:"
echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo "================================================="
