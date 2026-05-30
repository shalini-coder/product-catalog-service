param(
    [string]$ResourceGroup = "rg-product-catalog-dev"
)

Write-Host "Deleting resource group..."
az group delete --name $ResourceGroup --yes --no-wait

Write-Host "Waiting 120 seconds for cleanup..."
Start-Sleep -Seconds 120

Write-Host "Starting fresh deployment..."
& ".\scripts\deploy-vm-single.ps1"
