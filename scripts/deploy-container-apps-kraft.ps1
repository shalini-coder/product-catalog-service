param(
    [string]$ResourceGroup = "rg-product-catalog-poc",
    [string]$Location = "canadacentral",
    [string]$TemplateFile = "../infra/bicep/container-apps-kraft.bicep",
    [string]$ParameterFile = "../infra/bicep/parameters/container-apps-kraft-dev.bicepparam"
)

Write-Host "=== Container Apps Deployment with KRaft ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White
Write-Host "Template: $TemplateFile" -ForegroundColor White
Write-Host ""

# Check if resource group exists
Write-Host "Checking resource group..." -ForegroundColor Yellow
$rg = az group show --name $ResourceGroup 2>$null
if (-not $rg) {
    Write-Host "Creating resource group..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
    Write-Host "✅ Resource group created" -ForegroundColor Green
}
else {
    Write-Host "✅ Resource group exists" -ForegroundColor Green
}
Write-Host ""

# Validate Bicep template
Write-Host "Validating Bicep template..." -ForegroundColor Yellow
$validation = az deployment group validate `
    --resource-group $ResourceGroup `
    --template-file $TemplateFile `
    --parameters $ParameterFile 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Template validation failed:" -ForegroundColor Red
    Write-Host $validation -ForegroundColor Red
    exit 1
}
Write-Host "✅ Template validation passed" -ForegroundColor Green
Write-Host ""

# Deploy template
Write-Host "Deploying Container Apps (KRaft, PostgreSQL, Couchbase, Kafka UI)..." -ForegroundColor Yellow
Write-Host "(This may take 5-10 minutes)" -ForegroundColor Cyan
Write-Host ""

$deployment = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $TemplateFile `
    --parameters $ParameterFile `
    --output json 2>&1 | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed:" -ForegroundColor Red
    Write-Host $deployment -ForegroundColor Red
    exit 1
}

Write-Host "✅ Deployment completed!" -ForegroundColor Green
Write-Host ""

# Display outputs
if ($deployment.properties.outputs) {
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "DEPLOYMENT OUTPUTS" -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Application URL: $($deployment.properties.outputs.appUrl.value)" -ForegroundColor White
    Write-Host "Kafka UI: https://$($deployment.properties.outputs.kafkaUiFqdn.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Container Apps Environment ID:" -ForegroundColor Yellow
    Write-Host "$($deployment.properties.outputs.containerAppEnvId.value)" -ForegroundColor White
    Write-Host ""
}

Write-Host "Wait 2-3 minutes for containers to start, then test:" -ForegroundColor Yellow
Write-Host "  curl https://$($deployment.properties.outputs.appUrl.value)/actuator/health" -ForegroundColor Cyan
Write-Host ""
