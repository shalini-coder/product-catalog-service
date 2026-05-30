# Deployment Diagnostic & Recovery Guide

## 🔍 Step 1: Check What Was Created

```powershell
$RESOURCE_GROUP = "rg-product-catalog-dev"

Write-Host "Checking resources in resource group..."
az resource list --resource-group $RESOURCE_GROUP --output table
```

**Expected output should show:**
- ACR (Container Registry)
- VM (Virtual Machine) — **Missing?**

---

## 🛠️ Step 2: What Likely Happened

The deployment probably failed at one of these points:

1. ❌ **ACR push failed** (Docker image upload stuck or failed)
2. ❌ **Deployment script crashed** before VM creation
3. ❌ **Timeout** during image build

---

## ✅ Step 3: Restart Deployment

### **Option A: Run Updated Script (Recommended)**

```powershell
cd c:\Users\tvshali\Documents\azure-src\product-catalog-service

# Run the updated script with auto-retry logic
.\scripts\deploy-vm-single.ps1 -ResourceGroup "rg-product-catalog-dev"
```

The updated script now has:
- ✅ Auto-retry for ACR authentication
- ✅ Better error handling
- ✅ Admin credentials enabled by default

---

### **Option B: Quick Manual Deploy (Fastest)**

If you want to skip the image build and deploy with existing ACR:

```powershell
$RESOURCE_GROUP = "rg-product-catalog-dev"
$VM_NAME = "product-catalog-vm"
$LOCATION = "eastus"
$VM_SIZE = "Standard_B1s"

# Check what ACR exists
$acr = az acr list --resource-group $RESOURCE_GROUP --query "[0]" | ConvertFrom-Json
$ACR_LOGIN_SERVER = $acr.loginServer
Write-Host "Using existing ACR: $ACR_LOGIN_SERVER"

# Create VM
Write-Host "Creating VM..."
$vmResponse = az vm create `
  --resource-group $RESOURCE_GROUP `
  --name $VM_NAME `
  --image UbuntuLTS `
  --size $VM_SIZE `
  --generate-ssh-keys `
  --public-ip-address-allocation static

$vm = $vmResponse | ConvertFrom-Json
$VM_IP = $vm.publicIpAddress
Write-Host "✅ VM created: $VM_IP"

# Configure firewall
Write-Host "Configuring firewall..."
az network nsg rule create `
  --resource-group $RESOURCE_GROUP `
  --nsg-name "${VM_NAME}NSG" `
  --name "AllowSSH" `
  --priority 100 `
  --direction Inbound `
  --access Allow `
  --protocol Tcp `
  --destination-port-ranges 22 `
  --output none

az network nsg rule create `
  --resource-group $RESOURCE_GROUP `
  --nsg-name "${VM_NAME}NSG" `
  --name "AllowHTTP" `
  --priority 200 `
  --direction Inbound `
  --access Allow `
  --protocol Tcp `
  --destination-port-ranges 8080 `
  --output none

Write-Host "✅ Firewall configured"
Write-Host "VM IP: $VM_IP"
```

---

## 🚀 Step 4: Check If Docker Image Exists

Before recreating VM, verify the image was pushed:

```powershell
$RESOURCE_GROUP = "rg-product-catalog-dev"

# Get ACR name
$acrName = az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv

if ($acrName) {
    Write-Host "ACR found: $acrName"
    
    # List repositories
    Write-Host "Checking for images..."
    az acr repository list --name $acrName
    
    # List tags
    Write-Host "Image tags:"
    az acr repository show-tags --name $acrName --repository "product-catalog-service"
}
else {
    Write-Host "No ACR found - deployment needs to start from beginning"
}
```

---

## 💥 Step 5: If You Need to Restart Completely

```powershell
$RESOURCE_GROUP = "rg-product-catalog-dev"

# DELETE everything and start fresh
Write-Host "Deleting entire resource group..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

# Wait for deletion
Write-Host "Waiting for deletion (this takes 2-3 minutes)..."
Start-Sleep -Seconds 180

# Now run fresh deployment
Write-Host "Starting fresh deployment..."
.\scripts\deploy-vm-single.ps1
```

---

## 📋 Recommended Path Forward

1. **Check existing resources:**
   ```powershell
   az resource list --resource-group rg-product-catalog-dev --output table
   ```

2. **If ACR exists with image:**
   - Run Option B above (quick manual VM deploy)

3. **If ACR failed or no image:**
   - Delete resource group and restart: `.\scripts\deploy-vm-single.ps1`

4. **If you want to skip everything and test locally:**
   ```bash
   # Run locally first
   docker-compose up -d
   curl http://localhost:8080/actuator/health
   ```
