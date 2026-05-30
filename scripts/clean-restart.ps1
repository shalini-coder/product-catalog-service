# Clean Restart Deployment Script
# Deletes all resources and starts fresh

param(
    [string]$ResourceGroup = "rg-product-catalog-dev"
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🗑️  CLEAN RESTART - DELETING ALL RESOURCES"
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Delete resource group
Write-Host "📦 Step 1: Deleting resource group '$ResourceGroup'..."
Write-Host "   This may take 2-3 minutes..."
Write-Host ""

try {
    az group delete --name $ResourceGroup --yes --no-wait
    Write-Host "✅ Deletion started (running in background)"
}
catch {
    Write-Host "❌ Error deleting resource group: $($_.Exception.Message)"
    exit 1
}

# Step 2: Wait for deletion
Write-Host ""
Write-Host "⏳ Waiting for deletion to complete..."
$maxWait = 180  # 3 minutes
$elapsed = 0
$interval = 10

while ($elapsed -lt $maxWait) {
    try {
        $group = az group show --name $ResourceGroup --query "properties.provisioningState" -o tsv 2>$null
        if ([string]::IsNullOrEmpty($group)) {
            Write-Host "✅ Resource group deleted successfully"
            break
        }
    }
    catch {
        # Group doesn't exist anymore
        Write-Host "✅ Resource group deleted successfully"
        break
    }
    
    Write-Host "   Waiting... $([Math]::Min($elapsed + $interval, $maxWait))/$maxWait seconds"
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ CLEANUP COMPLETE"
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Step 3: Start fresh deployment
Write-Host "🚀 Starting fresh deployment..."
Write-Host ""

$scriptPath = Join-Path (Get-Location) "scripts\deploy-vm-single.ps1"

if (Test-Path $scriptPath) {
    Write-Host "Running: $scriptPath"
    & $scriptPath
}
else {
    Write-Host "❌ Deployment script not found at: $scriptPath"
    $currentPath = Get-Location
    Write-Host "   Please run from project root: $currentPath"
    exit 1
}
