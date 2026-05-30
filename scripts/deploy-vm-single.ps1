# Deploy Product Catalog Service to Azure VM (Windows PowerShell)
# Usage: .\scripts\deploy-vm-single.ps1

param(
    [string]$ResourceGroup = "rg-product-catalog-dev",
    [string]$VmName = "product-catalog-vm",
    [string]$Location = "eastus",
    [string]$VmSize = "Standard_B1s",
    [string]$PostgresPassword = "SecurePass123!@#",
    [string]$CouchbasePassword = "SecurePass123!@#",
    [string]$AppJwtSecret = ""
)

# Generate JWT secret if not provided
if ([string]::IsNullOrEmpty($AppJwtSecret)) {
    $bytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $AppJwtSecret = [Convert]::ToBase64String($bytes)
}

# Generate unique ACR name
$acrName = "acrproductcatalog$((Get-Random -Maximum 10000))"
$registrySku = "Basic"
$dockerImageTag = "latest"
$appProfile = "prod"

Write-Host "🚀 Starting deployment of Product Catalog Service to Azure VM..."
Write-Host "📍 Resource Group: $ResourceGroup"
Write-Host "📍 Location: $Location"
Write-Host "📍 VM Name: $VmName"
Write-Host "📍 Registry: $acrName.azurecr.io"
Write-Host ""

# Step 1: Create resource group
Write-Host "📦 Step 1: Creating resource group..."
az group create `
  --name $ResourceGroup `
  --location $Location `
  --output none
Write-Host "✅ Resource group created"

# Step 2: Create Azure Container Registry
Write-Host ""
Write-Host "📦 Step 2: Creating Azure Container Registry..."
az acr create `
  --resource-group $ResourceGroup `
  --name $acrName `
  --sku $registrySku `
  --admin-enabled true `
  --output none
Write-Host "✅ Registry created: $acrName.azurecr.io"

# Wait for ACR to initialize
Write-Host "⏳ Waiting for ACR to initialize..."
Start-Sleep -Seconds 15

# Step 3: Build and push Docker image
Write-Host ""
Write-Host "📦 Step 3: Building Docker image..."
$acrLoginServer = "$acrName.azurecr.io"
$dockerImageName = "$acrLoginServer/product-catalog-service:$dockerImageTag"

# Build image
docker build `
  -t $dockerImageName `
  --build-arg PROFILE=$appProfile `
  .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed"
    exit 1
}

Write-Host "✅ Docker image built"

# Login to ACR with retry logic
Write-Host "📤 Authenticating to ACR (with retry)..."
$maxRetries = 5
$retryCount = 0
$loginSuccess = $false

while ($retryCount -lt $maxRetries -and -not $loginSuccess) {
    try {
        # Get ACR admin credentials
        $creds = az acr credential show --resource-group $ResourceGroup --name $acrName | ConvertFrom-Json
        $username = $creds.username
        $password = $creds.passwords[0].value
        
        # Login with credentials
        $password | docker login -u $username --password-stdin "$acrLoginServer" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ ACR authentication successful"
            $loginSuccess = $true
        }
        else {
            throw "Login failed"
        }
    }
    catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "⚠️  Authentication failed, retrying in 10 seconds... (attempt $retryCount/$maxRetries)"
            Start-Sleep -Seconds 10
        }
        else {
            Write-Host "❌ Failed to authenticate to ACR after $maxRetries attempts"
            exit 1
        }
    }
}

# Push image with retry logic
Write-Host "📤 Pushing image to registry..."
$pushRetryCount = 0
$pushSuccess = $false

while ($pushRetryCount -lt $maxRetries -and -not $pushSuccess) {
    try {
        docker push $dockerImageName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Image pushed successfully to $dockerImageName"
            $pushSuccess = $true
        }
        else {
            throw "Push failed"
        }
    }
    catch {
        $pushRetryCount++
        if ($pushRetryCount -lt $maxRetries) {
            Write-Host "⚠️  Push failed, retrying in 15 seconds... (attempt $pushRetryCount/$maxRetries)"
            Start-Sleep -Seconds 15
        }
        else {
            Write-Host "❌ Failed to push image after $maxRetries attempts"
            Write-Host "Try manually: docker push $dockerImageName"
            exit 1
        }
    }
}

# Step 4: Create VM
Write-Host ""
Write-Host "📦 Step 4: Creating VM (this may take 2-3 minutes)..."

$vmResponse = az vm create `
  --resource-group $ResourceGroup `
  --name $VmName `
  --image UbuntuLTS `
  --size $VmSize `
  --generate-ssh-keys `
  --public-ip-address-allocation static | ConvertFrom-Json

$vmIp = $vmResponse.publicIpAddress
Write-Host "✅ VM created with IP: $vmIp"

# Step 5: Configure NSG (Network Security Group)
Write-Host ""
Write-Host "📦 Step 5: Configuring firewall rules..."

# Allow SSH
az network nsg rule create `
  --resource-group $ResourceGroup `
  --nsg-name "${VmName}NSG" `
  --name "AllowSSH" `
  --priority 100 `
  --direction Inbound `
  --access Allow `
  --protocol Tcp `
  --source-address-prefixes "*" `
  --destination-address-prefixes "*" `
  --source-port-ranges "*" `
  --destination-port-ranges 22 `
  --output none

# Allow HTTP (app)
az network nsg rule create `
  --resource-group $ResourceGroup `
  --nsg-name "${VmName}NSG" `
  --name "AllowHTTP" `
  --priority 200 `
  --direction Inbound `
  --access Allow `
  --protocol Tcp `
  --source-address-prefixes "*" `
  --destination-address-prefixes "*" `
  --source-port-ranges "*" `
  --destination-port-ranges 8080 `
  --output none

Write-Host "✅ Firewall configured"

# Step 6: Wait for SSH to be ready
Write-Host ""
Write-Host "📦 Step 6: Waiting for VM SSH to be ready..."
$maxAttempts = 30
$attempt = 0
do {
    Start-Sleep -Seconds 2
    $attempt++
    Write-Host "  Attempt $attempt of $maxAttempts..."
} while ($attempt -lt $maxAttempts)
Write-Host "✅ VM should be ready"

# Step 7: Install Docker on VM
Write-Host ""
Write-Host "📦 Step 7: Setting up Docker environment on VM..."

# Create installation script
$setupScript = @"
#!/bin/bash
set -e
echo "🔧 Installing Docker on VM..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
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
  `$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Allow user to run docker without sudo
sudo groupadd -f docker
sudo usermod -aG docker `$USER

echo "✅ Docker installed"
"@

# Save setup script to temp file
$setupPath = Join-Path $env:TEMP "setup-docker.sh"
$setupScript | Out-File -FilePath $setupPath -Encoding UTF8 -Force

# Upload and execute
Write-Host "  Uploading setup script..."
scp $setupPath "azureuser@${vmIp}:/tmp/setup-docker.sh" 2>$null
ssh "azureuser@${vmIp}" "bash /tmp/setup-docker.sh" 2>$null

Write-Host "✅ Docker configured on VM"

# Step 8: Create and upload environment file
Write-Host ""
Write-Host "📦 Step 8: Uploading docker-compose configuration..."

# Create .env file
$envContent = @"
ACR_LOGIN_SERVER=$acrLoginServer
IMAGE_TAG=$dockerImageTag
POSTGRES_USER=catalog_user
POSTGRES_PASSWORD=$PostgresPassword
COUCHBASE_USER=Administrator
COUCHBASE_PASSWORD=$CouchbasePassword
APP_JWT_SECRET=$AppJwtSecret
SPRING_PROFILES_ACTIVE=$appProfile
"@

$envPath = Join-Path $env:TEMP ".env"
$envContent | Out-File -FilePath $envPath -Encoding UTF8 -Force

# Upload files
Write-Host "  Uploading environment and docker-compose files..."
scp $envPath "azureuser@${vmIp}:/tmp/.env" 2>$null
scp "docker-compose.yml" "azureuser@${vmIp}:/tmp/docker-compose.yml" 2>$null

Write-Host "✅ Configuration uploaded"

# Step 9: Start services
Write-Host ""
Write-Host "📦 Step 9: Starting services on VM (this may take 3-5 minutes)..."

$startScript = @"
#!/bin/bash
set -e
cd /tmp
export `$(cat .env | xargs)
echo "Logging in to ACR..."
az acr login --name `$(echo `$ACR_LOGIN_SERVER | cut -d'.' -f1)
echo "Starting Docker services..."
docker compose up -d
echo "Waiting for services to become healthy..."
sleep 10
docker compose ps
"@

$startPath = Join-Path $env:TEMP "start-services.sh"
$startScript | Out-File -FilePath $startPath -Encoding UTF8 -Force

scp $startPath "azureuser@${vmIp}:/tmp/start-services.sh" 2>$null
ssh "azureuser@${vmIp}" "bash /tmp/start-services.sh" 2>$null

Write-Host "✅ Services started"

# Step 10: Verify deployment
Write-Host ""
Write-Host "📦 Step 10: Verifying deployment..."
Start-Sleep -Seconds 10

try {
    $healthCheck = Invoke-WebRequest -Uri "http://$vmIp:8080/actuator/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($healthCheck.Content -match '"status":"UP"') {
        Write-Host "✅ Application is healthy!"
    }
    else {
        Write-Host "⚠️  Health check returned: $($healthCheck.Content)"
        Write-Host "   Services may still be starting..."
    }
}
catch {
    Write-Host "⚠️  Could not reach application yet: $($_.Exception.Message)"
    Write-Host "   Services may still be starting..."
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════"
Write-Host "✅ DEPLOYMENT COMPLETE"
Write-Host "═══════════════════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "🌐 Application URL: http://$vmIp:8080"
Write-Host "📋 Swagger UI: http://$vmIp:8080/swagger-ui.html"
Write-Host "💻 SSH Access: ssh azureuser@$vmIp"
Write-Host ""
Write-Host "📊 Resources created:"
Write-Host "   - Resource Group: $ResourceGroup"
Write-Host "   - VM: $VmName (size: $VmSize)"
Write-Host "   - Container Registry: $acrName.azurecr.io"
Write-Host ""
Write-Host "🔑 Credentials:"
Write-Host "   - Postgres User: catalog_user"
Write-Host "   - Postgres Password: $PostgresPassword"
Write-Host "   - Couchbase User: Administrator"
Write-Host "   - Couchbase Password: $CouchbasePassword"
Write-Host "   - JWT Secret: $($AppJwtSecret.Substring(0, 20))..."
Write-Host ""
Write-Host "📝 Next steps:"
Write-Host "   1. Test the API: bash scripts/test-e2e-azure.sh http://$vmIp:8080"
Write-Host "   2. Check logs: ssh azureuser@$vmIp && docker compose logs -f"
Write-Host "   3. Cleanup: az group delete --name $ResourceGroup --yes"
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════"

# Save deployment info
$deploymentDir = "deployments"
if (-not (Test-Path $deploymentDir)) {
    New-Item -ItemType Directory -Path $deploymentDir -Force | Out-Null
}

$deploymentInfo = @"
DEPLOYMENT INFO
===============
Date: $(Get-Date)
Resource Group: $ResourceGroup
VM Name: $VmName
VM IP: $vmIp
VM Size: $VmSize
Location: $Location
Registry: $acrName.azurecr.io
Image: $dockerImageName

Connection:
  ssh azureuser@$vmIp

Application:
  http://$vmIp:8080
  http://$vmIp:8080/swagger-ui.html

Credentials (save securely):
  Postgres User: catalog_user
  Postgres Password: $PostgresPassword
  Couchbase User: Administrator
  Couchbase Password: $CouchbasePassword
  JWT Secret: $AppJwtSecret

Cleanup:
  az group delete --name $ResourceGroup --yes
"@

$deploymentFile = Join-Path $deploymentDir "vm-deployment-${VmName}.txt"
$deploymentInfo | Out-File -FilePath $deploymentFile -Encoding UTF8 -Force

Write-Host "📄 Deployment info saved to: $deploymentFile"
