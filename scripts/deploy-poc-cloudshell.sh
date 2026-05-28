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
LOCATION="eastus"
ACR_NAME="acrproductcatalogpoc$RANDOM"   # random suffix avoids name collisions
ACA_ENV="aca-env-poc"
IMAGE_NAME="product-catalog-service"
IMAGE_TAG="poc-$(git rev-parse --short HEAD 2>/dev/null || echo latest)"

echo ""
echo "================================================="
echo "  Product Catalog POC — Azure Cloud Shell Deploy"
echo "================================================="
echo "  Resource Group : $RESOURCE_GROUP"
echo "  Location       : $LOCATION"
echo "  ACR Name       : $ACR_NAME"
echo "================================================="
echo ""

# ── 1. Create Resource Group ──────────────────────────────────────────────────
echo ">>> [1/6] Creating resource group..."
az group create \
    --name     "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output   none
echo "    Done."

# ── 2. Create Azure Container Registry ───────────────────────────────────────
echo ">>> [2/6] Creating container registry: $ACR_NAME"
az acr create \
    --resource-group "$RESOURCE_GROUP" \
    --name           "$ACR_NAME" \
    --sku            Basic \
    --admin-enabled  true \
    --output         none
echo "    Done."

ACR_SERVER="${ACR_NAME}.azurecr.io"
FULL_IMAGE="${ACR_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

# ── 3. Build image IN AZURE (no local Docker required!) ───────────────────────
echo ">>> [3/6] Building Docker image in Azure (az acr build)..."
echo "    Image: $FULL_IMAGE"
echo "    This takes ~4-6 minutes the first time..."

az acr build \
    --registry        "$ACR_NAME" \
    --image           "${IMAGE_NAME}:${IMAGE_TAG}" \
    --image           "${IMAGE_NAME}:latest" \
    --file            Dockerfile \
    .                                          # sends current directory to ACR

echo "    Image built and stored in ACR."

# ── 4. Create Container Apps Environment ──────────────────────────────────────
echo ">>> [4/6] Creating Container Apps environment..."
az containerapp env create \
    --name           "$ACA_ENV" \
    --resource-group "$RESOURCE_GROUP" \
    --location       "$LOCATION" \
    --output         none
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
