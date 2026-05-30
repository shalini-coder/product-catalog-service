param(
    [string]$ResourceGroup = "rg-product-catalog-dev",
    [string]$VmName = "product-catalog-vm",
    [string]$Location = "eastus",
    [string]$VmSize = "Standard_B1s",
    [string]$PostgresPassword = "SecurePass123!@#",
    [string]$CouchbasePassword = "SecurePass123!@#",
    [string]$AppJwtSecret = ""
)

if ([string]::IsNullOrEmpty($AppJwtSecret)) {
    $bytes = New-Object byte[] 48
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $AppJwtSecret = [Convert]::ToBase64String($bytes)
}

$acrName = "acrproductcatalog$((Get-Random -Maximum 10000))"
$registrySku = "Basic"
$dockerImageTag = "latest"
$appProfile = "prod"

Write-Host "Starting deployment..." -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Location: $Location"
Write-Host "VM Name: $VmName"
Write-Host "Registry: $acrName.azurecr.io"
Write-Host ""

Write-Host "Step 1: Creating resource group..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none
Write-Host "Done" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Creating Azure Container Registry..." -ForegroundColor Yellow
az acr create --resource-group $ResourceGroup --name $acrName --sku $registrySku --admin-enabled true --output none
Write-Host "Done" -ForegroundColor Green
Start-Sleep -Seconds 15
Write-Host ""

Write-Host "Step 3: Building Docker image..." -ForegroundColor Yellow
$acrLoginServer = "$acrName.azurecr.io"
$dockerImageName = "$acrLoginServer/product-catalog-service:$dockerImageTag"

docker build -t $dockerImageName --build-arg PROFILE=$appProfile .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "Done" -ForegroundColor Green
Write-Host ""

Write-Host "Step 4: Authenticating to ACR..." -ForegroundColor Yellow
$maxRetries = 5
$retryCount = 0
$loginSuccess = $false

while ($retryCount -lt $maxRetries -and -not $loginSuccess) {
    try {
        $creds = az acr credential show --resource-group $ResourceGroup --name $acrName | ConvertFrom-Json
        $username = $creds.username
        $password = $creds.passwords[0].value
        
        $password | docker login -u $username --password-stdin "$acrLoginServer" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "ACR authentication successful" -ForegroundColor Green
            $loginSuccess = $true
        }
        else {
            throw "Login failed"
        }
    }
    catch {
        $retryCount++
        if ($retryCount -lt $maxRetries) {
            Write-Host "Retrying in 10 seconds... (attempt $retryCount/$maxRetries)" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
        else {
            Write-Host "Failed to authenticate to ACR" -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host ""

Write-Host "Step 5: Pushing image to ACR..." -ForegroundColor Yellow
$pushRetryCount = 0
$pushSuccess = $false

while ($pushRetryCount -lt $maxRetries -and -not $pushSuccess) {
    try {
        docker push $dockerImageName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Image pushed successfully" -ForegroundColor Green
            $pushSuccess = $true
        }
        else {
            throw "Push failed"
        }
    }
    catch {
        $pushRetryCount++
        if ($pushRetryCount -lt $maxRetries) {
            Write-Host "Retrying in 15 seconds... (attempt $pushRetryCount/$maxRetries)" -ForegroundColor Yellow
            Start-Sleep -Seconds 15
        }
        else {
            Write-Host "Failed to push image" -ForegroundColor Red
            exit 1
        }
    }
}
Write-Host ""

Write-Host "Step 6: Creating VM..." -ForegroundColor Yellow
$vmResponse = az vm create --resource-group $ResourceGroup --name $VmName --image UbuntuLTS --size $VmSize --generate-ssh-keys --public-ip-address-allocation static | ConvertFrom-Json
$vmIp = $vmResponse.publicIpAddress
Write-Host "VM created: $vmIp" -ForegroundColor Green
Write-Host ""

Write-Host "Step 7: Configuring firewall..." -ForegroundColor Yellow
az network nsg rule create --resource-group $ResourceGroup --nsg-name "${VmName}NSG" --name "AllowSSH" --priority 100 --direction Inbound --access Allow --protocol Tcp --destination-port-ranges 22 --output none
az network nsg rule create --resource-group $ResourceGroup --nsg-name "${VmName}NSG" --name "AllowHTTP" --priority 200 --direction Inbound --access Allow --protocol Tcp --destination-port-ranges 8080 --output none
Write-Host "Done" -ForegroundColor Green
Write-Host ""

Write-Host "Step 8: Installing Docker on VM..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

$setupScript = @"
#!/bin/bash
set -e
sudo apt-get update -qq
sudo apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu `$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo groupadd -f docker
sudo usermod -aG docker `$USER
echo "Done"
"@

$setupPath = Join-Path $env:TEMP "setup-docker.sh"
$setupScript | Out-File -FilePath $setupPath -Encoding UTF8 -Force

scp $setupPath "azureuser@${vmIp}:/tmp/setup-docker.sh" 2>$null
ssh "azureuser@${vmIp}" "bash /tmp/setup-docker.sh" 2>$null
Write-Host "Done" -ForegroundColor Green
Write-Host ""

Write-Host "Step 9: Uploading configuration..." -ForegroundColor Yellow

$envContent = "ACR_LOGIN_SERVER=$acrLoginServer`nIMAGE_TAG=$dockerImageTag`nPOSTGRES_USER=catalog_user`nPOSTGRES_PASSWORD=$PostgresPassword`nCOUCHBASE_USER=Administrator`nCOUCHBASE_PASSWORD=$CouchbasePassword`nAPP_JWT_SECRET=$AppJwtSecret`nSPRING_PROFILES_ACTIVE=$appProfile"

$envPath = Join-Path $env:TEMP ".env"
$envContent | Out-File -FilePath $envPath -Encoding UTF8 -Force

scp $envPath "azureuser@${vmIp}:/tmp/.env" 2>$null
scp "docker-compose.yml" "azureuser@${vmIp}:/tmp/docker-compose.yml" 2>$null
Write-Host "Done" -ForegroundColor Green
Write-Host ""

Write-Host "Step 10: Starting services..." -ForegroundColor Yellow

$startScript = @"
#!/bin/bash
set -e
cd /tmp
export `$(cat .env | xargs)
echo "Logging in to ACR..."
az acr login --name `$(echo `$ACR_LOGIN_SERVER | cut -d'.' -f1)
echo "Starting services..."
docker compose up -d
sleep 10
docker compose ps
"@

$startPath = Join-Path $env:TEMP "start-services.sh"
$startScript | Out-File -FilePath $startPath -Encoding UTF8 -Force

scp $startPath "azureuser@${vmIp}:/tmp/start-services.sh" 2>$null
ssh "azureuser@${vmIp}" "bash /tmp/start-services.sh" 2>$null
Write-Host "Done" -ForegroundColor Green
Write-Host ""

Write-Host "Step 11: Verifying deployment..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

try {
    $health = Invoke-WebRequest -Uri "http://$vmIp:8080/actuator/health" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    if ($health.Content -match '"status":"UP"') {
        Write-Host "Application is healthy!" -ForegroundColor Green
    }
}
catch {
    Write-Host "Services still starting..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application URL: http://$vmIp:8080" -ForegroundColor White
Write-Host "Swagger UI: http://$vmIp:8080/swagger-ui.html" -ForegroundColor White
Write-Host "SSH: ssh azureuser@$vmIp" -ForegroundColor White
Write-Host ""
Write-Host "Credentials:" -ForegroundColor White
Write-Host "  Postgres: catalog_user / $PostgresPassword" -ForegroundColor White
Write-Host "  Couchbase: Administrator / $CouchbasePassword" -ForegroundColor White
Write-Host ""
Write-Host "Cleanup: az group delete --name $ResourceGroup --yes" -ForegroundColor Yellow
Write-Host ""
