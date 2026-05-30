# ACR 502 Bad Gateway — Quick Fixes

## What Happened?
Your error: `502 Bad Gateway` from Azure Container Registry

This typically means:
- ✅ ACR was just created and is still initializing
- ✅ Network connectivity issue
- ❌ (Rare) ACR service issue

---

## ✅ Solution: Try This Now

### **Quick Fix (Copy & Paste)**

```powershell
# Your ACR details (from error message)
$acrName = "acrproductcatalog28425"
$RESOURCE_GROUP = "rg-product-catalog-dev"
$ACR_LOGIN_SERVER = "$acrName.azurecr.io"

# 1. Enable admin access (if not already)
Write-Host "Enabling admin access..."
az acr update --resource-group $RESOURCE_GROUP --name $acrName --admin-enabled true

# 2. Get credentials
Write-Host "Getting credentials..."
$creds = az acr credential show --resource-group $RESOURCE_GROUP --name $acrName | ConvertFrom-Json
$username = $creds.username
$password = $creds.passwords[0].value

# 3. Login to ACR
Write-Host "Logging in..."
$password | docker login -u $username --password-stdin "$ACR_LOGIN_SERVER"

# 4. Rebuild and push
Write-Host "Building image..."
docker build -t "$ACR_LOGIN_SERVER/product-catalog-service:latest" .

Write-Host "Pushing..."
docker push "$ACR_LOGIN_SERVER/product-catalog-service:latest"

Write-Host "✅ Done!"
```

---

## 🔄 If That Doesn't Work

### **Option 1: Wait & Retry**
```powershell
Write-Host "Waiting 60 seconds for ACR to stabilize..."
Start-Sleep -Seconds 60
# Then run the Quick Fix above again
```

### **Option 2: Recreate ACR**
```powershell
# Delete old ACR
az acr delete --resource-group $RESOURCE_GROUP --name $acrName --yes

# Create new one (with admin enabled)
$newAcrName = "acrproductcatalog$((Get-Random -Maximum 100000))"
az acr create `
  --resource-group $RESOURCE_GROUP `
  --name $newAcrName `
  --sku Basic `
  --admin-enabled true

# Update your variables
$acrName = $newAcrName
$ACR_LOGIN_SERVER = "$acrName.azurecr.io"

# Then run the Quick Fix above
```

### **Option 3: Use Docker Hub Temporarily**
```powershell
# Push to Docker Hub instead
docker tag product-catalog-service:latest your-username/product-catalog-service:latest
docker login  # Login with Docker Hub credentials
docker push your-username/product-catalog-service:latest

# Update docker-compose.yml to use this image
```

---

## 📊 Diagnosis: Check ACR Status

```powershell
$acrName = "acrproductcatalog28425"
$RESOURCE_GROUP = "rg-product-catalog-dev"

# Check ACR exists and is active
az acr show --resource-group $RESOURCE_GROUP --name $acrName

# Test ACR connectivity
$testUrl = "https://$acrName.azurecr.io/v2/"
Invoke-WebRequest -Uri $testUrl -UseBasicParsing -ErrorAction SilentlyContinue | Select-Object StatusCode
```

---

## 🚀 Next Steps

**After successful push:**

1. Continue with VM creation (Step 4 in deployment)
2. Upload docker-compose to VM
3. Start services

The **updated deployment script** now has automatic retry logic, so you can just run:

```powershell
.\scripts\deploy-vm-single.ps1
```

It will automatically handle ACR initialization delays and retry authentication.

---

## ⚡ Quick Reference

| Issue | Fix |
|-------|-----|
| 502 Bad Gateway | Wait 60 sec, run Quick Fix above |
| Connection refused | Enable admin: `az acr update --admin-enabled true` |
| Unauthorized | Get fresh creds: `az acr credential show` |
| Still failing? | Delete ACR and recreate with admin enabled |

