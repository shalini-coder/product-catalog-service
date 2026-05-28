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
FULL_IMAGE="${ACR_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

# ── 3. Build and push Docker image ────────────────────────────────────────────
echo ">>> [3/6] Building and pushing Docker image..."
echo "    Image: $FULL_IMAGE"

# Try ACR Tasks first; fall back to local docker build+push if Tasks are blocked
if az acr build \
        --registry  "$ACR_NAME" \
        --image     "${IMAGE_NAME}:${IMAGE_TAG}" \
        --image     "${IMAGE_NAME}:latest" \
        --file      Dockerfile \
        . 2>&1 | tee /tmp/acr_build.log | grep -v "TasksOperationsNotAllowed"; then
    echo "    Image built and stored in ACR (via ACR Tasks)."
else
    if grep -q "TasksOperationsNotAllowed" /tmp/acr_build.log; then
        echo "    ACR Tasks blocked on this subscription — falling back to docker build + push..."
        echo "    Logging into ACR..."
        az acr login --name "$ACR_NAME"

        echo "    Building image locally (Cloud Shell Docker)..."
        docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f Dockerfile .
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE"
        docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${ACR_SERVER}/${IMAGE_NAME}:latest"

        echo "    Pushing to ACR..."
        docker push "$FULL_IMAGE"
        docker push "${ACR_SERVER}/${IMAGE_NAME}:latest"
        echo "    Image pushed to ACR (via docker push)."
    else
        echo "ERROR: Image build failed. See /tmp/acr_build.log for details."
        exit 1
    fi
fi

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
