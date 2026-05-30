#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# deploy-vm-single.sh — Deploy entire stack to single B1s VM on Azure
#
# Usage:
#   ./scripts/deploy-vm-single.sh
#
# Prerequisites:
#   - Azure CLI installed (az login already done)
#   - Docker installed (for building image locally)
#   - SSH key generated (or provide --ssh-key-values)
# ──────────────────────────────────────────────────────────────────────────────

set -e

# ── Configuration ────────────────────────────────────────────────────────────
RESOURCE_GROUP="rg-product-catalog-dev"
VM_NAME="product-catalog-vm"
LOCATION="eastus"
IMAGE_NAME="UbuntuLTS"
VM_SIZE="Standard_B1s"  # Free tier eligible (1 vCPU, 1 GB RAM)
ACR_NAME="acrproductcatalog${RANDOM}"  # Globally unique
REGISTRY_SKU="Basic"

# Docker image
DOCKER_IMAGE_TAG="latest"
APP_PROFILE="prod"

# Secrets (CHANGE THESE!)
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-SecurePass123!@#}"
COUCHBASE_PASSWORD="${COUCHBASE_PASSWORD:-SecurePass123!@#}"
APP_JWT_SECRET="${APP_JWT_SECRET:-$(openssl rand -base64 48)}"

echo "🚀 Starting deployment of Product Catalog Service to Azure VM..."
echo "📍 Resource Group: $RESOURCE_GROUP"
echo "📍 Location: $LOCATION"
echo "📍 VM Name: $VM_NAME"
echo "📍 Registry: $ACR_NAME.azurecr.io"
echo ""

# ── Step 1: Create resource group ────────────────────────────────────────────
echo "📦 Step 1: Creating resource group..."
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none
echo "✅ Resource group created"

# ── Step 2: Create Azure Container Registry ─────────────────────────────────
echo ""
echo "📦 Step 2: Creating Azure Container Registry..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku "$REGISTRY_SKU" \
  --output none
echo "✅ Registry created: $ACR_NAME.azurecr.io"

# ── Step 3: Build and push Docker image ──────────────────────────────────────
echo ""
echo "📦 Step 3: Building Docker image..."
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
DOCKER_IMAGE_NAME="$ACR_LOGIN_SERVER/product-catalog-service:$DOCKER_IMAGE_TAG"

# Build image locally
docker build \
  -t "$DOCKER_IMAGE_NAME" \
  --build-arg PROFILE="$APP_PROFILE" \
  .
echo "✅ Docker image built"

# Login to ACR and push
echo "📤 Pushing image to registry..."
az acr login --name "$ACR_NAME"
docker push "$DOCKER_IMAGE_NAME"
echo "✅ Image pushed to $DOCKER_IMAGE_NAME"

# ── Step 4: Create VM ────────────────────────────────────────────────────────
echo ""
echo "📦 Step 4: Creating VM (this may take 2-3 minutes)..."
VM_IP=$(az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --image "$IMAGE_NAME" \
  --size "$VM_SIZE" \
  --generate-ssh-keys \
  --public-ip-address-allocation static \
  --query "publicIpAddress" \
  -o tsv)

echo "✅ VM created with IP: $VM_IP"

# ── Step 5: Configure NSG (Network Security Group) ──────────────────────────
echo ""
echo "📦 Step 5: Configuring firewall rules..."

# Allow SSH
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "${VM_NAME}NSG" \
  --name "AllowSSH" \
  --priority 100 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "*" \
  --destination-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-port-ranges 22 \
  --output none

# Allow HTTP (app)
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "${VM_NAME}NSG" \
  --name "AllowHTTP" \
  --priority 200 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "*" \
  --destination-address-prefixes "*" \
  --source-port-ranges "*" \
  --destination-port-ranges 8080 \
  --output none

echo "✅ Firewall configured"

# ── Step 6: Prepare and upload setup script ──────────────────────────────────
echo ""
echo "📦 Step 6: Setting up Docker environment on VM..."

# Create setup script
SETUP_SCRIPT=$(mktemp)
cat > "$SETUP_SCRIPT" << 'VMSCRIPT'
#!/bin/bash
set -e

echo "🔧 Installing Docker on VM..."
sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repo
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Allow user to run docker without sudo
sudo groupadd -f docker
sudo usermod -aG docker $USER

echo "✅ Docker installed"
VMSCRIPT

scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "$SETUP_SCRIPT" "azureuser@$VM_IP:/tmp/setup-docker.sh"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "azureuser@$VM_IP" "bash /tmp/setup-docker.sh"
echo "✅ Docker configured on VM"

# ── Step 7: Upload docker-compose file ───────────────────────────────────────
echo ""
echo "📦 Step 7: Uploading docker-compose configuration..."

# Create environment file
ENV_FILE=$(mktemp)
cat > "$ENV_FILE" << ENV_CONTENT
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
IMAGE_TAG=$DOCKER_IMAGE_TAG
POSTGRES_USER=catalog_user
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
COUCHBASE_USER=Administrator
COUCHBASE_PASSWORD=$COUCHBASE_PASSWORD
APP_JWT_SECRET=$APP_JWT_SECRET
SPRING_PROFILES_ACTIVE=$APP_PROFILE
ENV_CONTENT

# Upload docker-compose and env file
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "$ENV_FILE" "azureuser@$VM_IP:/tmp/.env"
scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "docker-compose.yml" "azureuser@$VM_IP:/tmp/docker-compose.yml"

echo "✅ Configuration uploaded"

# ── Step 8: Start services on VM ─────────────────────────────────────────────
echo ""
echo "📦 Step 8: Starting services on VM (this may take 3-5 minutes)..."

START_SCRIPT=$(mktemp)
cat > "$START_SCRIPT" << 'VMSTARTSCRIPT'
#!/bin/bash
set -e

cd /tmp

# Load environment
export $(cat .env | xargs)

# Log in to ACR
echo "Logging in to ACR..."
az acr login --name $(echo $ACR_LOGIN_SERVER | cut -d'.' -f1)

# Start services
echo "Starting Docker services..."
docker compose up -d

echo "Waiting for services to become healthy..."
sleep 10

# Check services
echo "Checking service status..."
docker compose ps

echo "✅ All services started!"
VMSTARTSCRIPT

scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "$START_SCRIPT" "azureuser@$VM_IP:/tmp/start-services.sh"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa "azureuser@$VM_IP" "bash /tmp/start-services.sh"

echo "✅ Services started"

# ── Step 9: Verify deployment ────────────────────────────────────────────────
echo ""
echo "📦 Step 9: Verifying deployment..."
sleep 10

HEALTH_CHECK=$(curl -s "http://$VM_IP:8080/actuator/health" 2>/dev/null || echo '{"status":"DOWN"}')
if echo "$HEALTH_CHECK" | grep -q "UP"; then
  echo "✅ Application is healthy!"
else
  echo "⚠️  Health check returned: $HEALTH_CHECK"
  echo "   Services may still be starting..."
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "✅ DEPLOYMENT COMPLETE"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""
echo "🌐 Application URL: http://$VM_IP:8080"
echo "📋 Swagger UI: http://$VM_IP:8080/swagger-ui.html"
echo "💻 SSH Access: ssh azureuser@$VM_IP"
echo ""
echo "📊 Resources created:"
echo "   - Resource Group: $RESOURCE_GROUP"
echo "   - VM: $VM_NAME (size: $VM_SIZE)"
echo "   - Container Registry: $ACR_NAME.azurecr.io"
echo ""
echo "🔑 Credentials:"
echo "   - Postgres User: catalog_user"
echo "   - Postgres Password: $POSTGRES_PASSWORD"
echo "   - Couchbase User: Administrator"
echo "   - Couchbase Password: $COUCHBASE_PASSWORD"
echo "   - JWT Secret: ${APP_JWT_SECRET:0:20}..."
echo ""
echo "📝 Next steps:"
echo "   1. Test the API (see test-e2e.sh)"
echo "   2. Check logs: ssh azureuser@$VM_IP && docker compose logs -f"
echo "   3. Cleanup: az group delete --name $RESOURCE_GROUP --yes"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════"

# Save deployment info
mkdir -p deployments
cat > "deployments/vm-deployment-${VM_NAME}.txt" << INFO
DEPLOYMENT INFO
===============
Date: $(date)
Resource Group: $RESOURCE_GROUP
VM Name: $VM_NAME
VM IP: $VM_IP
VM Size: $VM_SIZE
Location: $LOCATION
Registry: $ACR_NAME.azurecr.io
Image: $DOCKER_IMAGE_NAME

Connection:
  ssh azureuser@$VM_IP

Application:
  http://$VM_IP:8080
  http://$VM_IP:8080/swagger-ui.html

Credentials (save securely):
  Postgres User: catalog_user
  Postgres Password: $POSTGRES_PASSWORD
  Couchbase User: Administrator
  Couchbase Password: $COUCHBASE_PASSWORD
  JWT Secret: $APP_JWT_SECRET

Cleanup:
  az group delete --name $RESOURCE_GROUP --yes
INFO

echo "📄 Deployment info saved to: deployments/vm-deployment-${VM_NAME}.txt"
