# =============================================================================
# deploy-poc.ps1  —  One-click POC deployment to Azure
#
# What it does:
#   1. Checks / installs Azure CLI
#   2. Logs you in to Azure
#   3. Creates a Resource Group + Azure Container Registry
#   4. Builds your app Docker image and pushes it to ACR
#   5. Deploys the FULL STACK (postgres + couchbase + kafka + app) on
#      Azure Container Apps — all as Docker containers, no managed services.
#   6. Prints the public URL and Swagger UI link
#
# Run from the repo root:
#   cd C:\Users\tvshali\Documents\product-catalog-service
#   .\scripts\deploy-poc.ps1
# =============================================================================

param(
    [string] $ResourceGroup  = "rg-product-catalog-poc",
    [string] $Location       = "eastus",
    [string] $AcrName        = "acrproductcatalogpoc",   # must be globally unique, lowercase, 5-50 chars
    [string] $AcaEnvName     = "aca-env-poc",
    [string] $AppName        = "product-catalog-poc"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Step([string]$msg) {
    Write-Host "`n===  $msg  ===" -ForegroundColor Cyan
}

function Write-Ok([string]$msg) {
    Write-Host "  ✓  $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "  !  $msg" -ForegroundColor Yellow
}

# ── Step 1: Check / install Azure CLI ─────────────────────────────────────────

Write-Step "Checking Azure CLI"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Warn "Azure CLI not found. Installing via winget..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Microsoft.AzureCLI --exact --silent --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host @"

  Azure CLI is not installed and winget is not available.
  Please install it manually:
    https://aka.ms/installazurecliwindows

  After installing, re-run this script.
"@
        exit 1
    }

    # Refresh PATH so 'az' is found in this session
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

$azVersion = (az version --output json | ConvertFrom-Json).'azure-cli'
Write-Ok "Azure CLI $azVersion"

# ── Step 2: Login ─────────────────────────────────────────────────────────────

Write-Step "Logging in to Azure"

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Warn "Not logged in — opening browser for login..."
    az login
    $account = az account show --output json | ConvertFrom-Json
}

Write-Ok "Logged in as: $($account.user.name)"
Write-Ok "Subscription : $($account.name) ($($account.id))"

# ── Step 3: Install Container Apps CLI extension ──────────────────────────────

Write-Step "Ensuring Container Apps CLI extension"
az extension add --name containerapp --upgrade --only-show-errors
Write-Ok "containerapp extension ready"

# Register providers (safe to run even if already registered)
Write-Step "Registering Azure resource providers (first-time only, may take a minute)"
az provider register --namespace Microsoft.App            --wait
az provider register --namespace Microsoft.OperationalInsights --wait
Write-Ok "Providers registered"

# ── Step 4: Create Resource Group ─────────────────────────────────────────────

Write-Step "Creating Resource Group: $ResourceGroup ($Location)"

az group create `
    --name     $ResourceGroup `
    --location $Location `
    --output   none

Write-Ok "Resource group ready"

# ── Step 5: Create Azure Container Registry ────────────────────────────────────

Write-Step "Creating Azure Container Registry: $AcrName"

az acr create `
    --resource-group $ResourceGroup `
    --name           $AcrName `
    --sku            Basic `
    --admin-enabled  true `
    --output         none

$acrServer = az acr show `
    --name           $AcrName `
    --resource-group $ResourceGroup `
    --query          "loginServer" `
    --output         tsv

Write-Ok "ACR: $acrServer"

# ── Step 6: Build & Push app image ────────────────────────────────────────────

Write-Step "Building app Docker image and pushing to ACR"
Write-Warn "This may take 3-5 minutes on first build (downloading base images)..."

$imageTag = "poc-$(git rev-parse --short HEAD 2>$null)"
if ($LASTEXITCODE -ne 0) { $imageTag = "poc-latest" }

$fullImage = "${acrServer}/product-catalog-service:${imageTag}"

# Build locally, tag, push
docker build --tag $fullImage --file Dockerfile .
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

# ACR login via Docker
az acr login --name $AcrName
docker push $fullImage
if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }

Write-Ok "Image pushed: $fullImage"

# ── Step 7: Create Container Apps Environment ──────────────────────────────────

Write-Step "Creating Container Apps Environment: $AcaEnvName"

az containerapp env create `
    --name           $AcaEnvName `
    --resource-group $ResourceGroup `
    --location       $Location `
    --output         none

Write-Ok "Container Apps Environment ready"

# ── Step 8: Deploy the full stack (all Docker containers) ─────────────────────

Write-Step "Deploying full stack to Azure Container Apps"
Write-Warn "Deploying: Postgres + Couchbase + Kafka + App (all as Docker containers)..."

$env:ACR_IMAGE = $fullImage

az containerapp compose create `
    --environment    $AcaEnvName `
    --resource-group $ResourceGroup `
    --compose-file-path docker-compose.poc.yml `
    --output         none

if ($LASTEXITCODE -ne 0) {
    Write-Warn "compose create failed — trying individual container approach..."
    # Fallback: deploy just the app container (requires manual infra for the rest)
    az containerapp create `
        --name              $AppName `
        --resource-group    $ResourceGroup `
        --environment       $AcaEnvName `
        --image             $fullImage `
        --target-port       8080 `
        --ingress           external `
        --registry-server   $acrServer `
        --registry-username $(az acr credential show --name $AcrName --query username -o tsv) `
        --registry-password $(az acr credential show --name $AcrName --query passwords[0].value -o tsv) `
        --env-vars `
            SPRING_PROFILES_ACTIVE=prod `
            "APP_SECURITY_JWT_SECRET=poc-jwt-secret-change-this-for-real-use-must-be-64chars!!" `
        --output none
}

# ── Step 9: Get the URL ────────────────────────────────────────────────────────

Write-Step "Getting application URL"

$appFqdn = az containerapp show `
    --name           $AppName `
    --resource-group $ResourceGroup `
    --query          "properties.configuration.ingress.fqdn" `
    --output         tsv 2>$null

if (-not $appFqdn) {
    # Try with the compose service name (lowercase)
    $appFqdn = az containerapp show `
        --name           "app" `
        --resource-group $ResourceGroup `
        --query          "properties.configuration.ingress.fqdn" `
        --output         tsv 2>$null
}

# ── Done! ─────────────────────────────────────────────────────────────────────

Write-Host "`n" + ("─" * 60) -ForegroundColor Green
Write-Host "  POC DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host ("─" * 60) -ForegroundColor Green

if ($appFqdn) {
    Write-Host @"

  App URL     : https://$appFqdn
  Swagger UI  : https://$appFqdn/swagger-ui/index.html
  Health      : https://$appFqdn/actuator/health

  Resource Group : $ResourceGroup
  ACR            : $acrServer
  Image          : $fullImage

  To tear everything down (stops billing):
    az group delete --name $ResourceGroup --yes --no-wait
"@ -ForegroundColor White
} else {
    Write-Host @"

  Deployment submitted. Find the URL with:
    az containerapp list --resource-group $ResourceGroup --query "[].properties.configuration.ingress.fqdn" -o tsv

  To tear everything down:
    az group delete --name $ResourceGroup --yes --no-wait
"@ -ForegroundColor White
}

Write-Host ("─" * 60) -ForegroundColor Green
