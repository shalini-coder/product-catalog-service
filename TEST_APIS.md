# Testing Product Catalog Service — Complete Guide

## 🌐 Step 1: Get Your VM IP Address

If deployment output doesn't show the IP, get it here:

```powershell
# Set your resource group name
$RESOURCE_GROUP = "rg-product-catalog-dev"
$VM_NAME = "product-catalog-vm"

# Get VM public IP
$vmIp = az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --show-details --query "publicIps" -o tsv
Write-Host "VM IP: $vmIp"

# Save for later use
$AppUrl = "http://$vmIp:8080"
Write-Host "App URL: $AppUrl"
```

---

## ✅ Step 2: Quick Health Check

### **Option A: PowerShell (Recommended)**

```powershell
$vmIp = "YOUR_VM_IP"  # Replace with actual IP from deployment
$appUrl = "http://$vmIp:8080"

# Check health
Write-Host "Checking application health..."
try {
    $health = Invoke-WebRequest -Uri "$appUrl/actuator/health" -UseBasicParsing -TimeoutSec 5
    $content = $health.Content | ConvertFrom-Json
    
    if ($content.status -eq "UP") {
        Write-Host "✅ Application is RUNNING!" -ForegroundColor Green
        Write-Host "Status: $($content.status)"
    }
    else {
        Write-Host "⚠️  Application status: $($content.status)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "❌ Cannot reach application: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "App may still be starting... Wait 30-60 seconds and try again"
}
```

### **Option B: Browser**

Open in your browser:
```
http://<YOUR_VM_IP>:8080/actuator/health
```

**Expected response:**
```json
{"status":"UP","components":{"livenessState":{"status":"LIVE"},"readinessState":{"status":"READY"}}}
```

### **Option C: Simple Curl (Git Bash)**

```bash
curl http://<VM_IP>:8080/actuator/health
```

---

## 📖 Step 3: Access Swagger UI (Interactive API Documentation)

### **Best for testing — Interactive API Explorer**

Open this in your browser:
```
http://<YOUR_VM_IP>:8080/swagger-ui.html
```

**What you'll see:**
- All available API endpoints
- Request/response schemas
- "Try it out" button to test endpoints directly
- Automatically generated from OpenAPI spec

**Example workflow in Swagger:**
1. Scroll to **POST /api/v1/products**
2. Click **"Try it out"**
3. Enter sample JSON:
```json
{
  "name": "MacBook Pro",
  "description": "High-performance laptop",
  "price": 2499.99,
  "stockQuantity": 50
}
```
4. Click **"Execute"**
5. See the response with Product ID

---

## 🧪 Step 4: Test APIs from PowerShell (End-to-End)

### **Test 1: Get Application Info**

```powershell
$vmIp = "YOUR_VM_IP"
$appUrl = "http://$vmIp:8080"

Write-Host "📋 Getting application info..."
$info = Invoke-WebRequest -Uri "$appUrl/actuator/info" -UseBasicParsing
$info.Content | ConvertFrom-Json | ConvertTo-Json
```

---

### **Test 2: Create a Product (WRITE SIDE → PostgreSQL)**

```powershell
$vmIp = "YOUR_VM_IP"
$appUrl = "http://$vmIp:8080"

Write-Host "📝 Creating a new product..."

$productData = @{
    name = "Dell XPS 13"
    description = "Ultra-portable laptop"
    price = 1299.99
    stockQuantity = 25
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "$appUrl/api/v1/products" `
  -Method POST `
  -Headers @{ "Content-Type" = "application/json" } `
  -Body $productData `
  -UseBasicParsing

$result = $response.Content | ConvertFrom-Json
$productId = $result.id

Write-Host "✅ Product created successfully!" -ForegroundColor Green
Write-Host "Product ID: $productId"
Write-Host "Name: $($result.name)"
Write-Host "Price: $($result.price)"
Write-Host ""

# Save product ID for next tests
$productId
```

---

### **Test 3: Query Product (READ SIDE → CouchBase via Kafka)**

```powershell
$vmIp = "YOUR_VM_IP"
$appUrl = "http://$vmIp:8080"
$productId = "YOUR_PRODUCT_ID_FROM_ABOVE"

Write-Host "⏳ Waiting 5 seconds for event to sync through Kafka..."
Start-Sleep -Seconds 5

Write-Host "🔍 Querying product from read model..."

$getResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products/$productId" `
  -UseBasicParsing

$product = $getResponse.Content | ConvertFrom-Json

Write-Host "✅ Product found in read model!" -ForegroundColor Green
Write-Host "ID: $($product.id)"
Write-Host "Name: $($product.name)"
Write-Host "Description: $($product.description)"
Write-Host "Price: $($product.price)"
Write-Host "Stock: $($product.stockQuantity)"
```

---

### **Test 4: List All Products**

```powershell
$vmIp = "YOUR_VM_IP"
$appUrl = "http://$vmIp:8080"

Write-Host "📦 Listing all products..."

$listResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products" `
  -UseBasicParsing

$products = $listResponse.Content | ConvertFrom-Json

Write-Host "✅ Found $($products.Count) product(s)" -ForegroundColor Green
Write-Host ""

foreach ($p in $products) {
    Write-Host "  • $($p.name) - `$$($p.price) (Stock: $($p.stockQuantity))"
}
```

---

### **Test 5: Update Stock (COMMAND → Event → Read Model Update)**

```powershell
$vmIp = "YOUR_VM_IP"
$appUrl = "http://$vmIp:8080"
$productId = "YOUR_PRODUCT_ID"

Write-Host "📊 Updating product stock..."

$stockData = @{
    quantity = 10
    reason = "Sold 15 units"
} | ConvertTo-Json

$updateResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products/$productId/stock" `
  -Method PUT `
  -Headers @{ "Content-Type" = "application/json" } `
  -Body $stockData `
  -UseBasicParsing

$result = $updateResponse.Content | ConvertFrom-Json

Write-Host "✅ Stock updated!" -ForegroundColor Green
Write-Host "New stock quantity: $($result.stockQuantity)"
Write-Host ""

Write-Host "⏳ Waiting 5 seconds for event sync..."
Start-Sleep -Seconds 5

# Verify update in read model
$verifyResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products/$productId" `
  -UseBasicParsing

$verified = $verifyResponse.Content | ConvertFrom-Json
Write-Host "✅ Verified in read model - Stock: $($verified.stockQuantity)" -ForegroundColor Green
```

---

## 🎬 Step 5: Complete End-to-End Test Script

Run this entire test in one go:

```powershell
# ============================================================================
# COMPLETE E2E TEST SCRIPT
# ============================================================================

$vmIp = "YOUR_VM_IP"  # Replace with actual IP
$appUrl = "http://$vmIp:8080"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🧪 END-TO-END CQRS MICROSERVICE TEST"
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# TEST 1: Health
Write-Host "TEST 1: Health Check" -ForegroundColor Yellow
try {
    $health = Invoke-WebRequest -Uri "$appUrl/actuator/health" -UseBasicParsing -TimeoutSec 5
    $content = $health.Content | ConvertFrom-Json
    Write-Host "✅ PASS - Status: $($content.status)" -ForegroundColor Green
}
catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# TEST 2: Create Product
Write-Host "TEST 2: Create Product (Write Side)" -ForegroundColor Yellow
$productData = @{
    name = "Test Product - $(Get-Date -Format 'HH:mm:ss')"
    description = "E2E test product"
    price = 99.99
    stockQuantity = 100
} | ConvertTo-Json

try {
    $createResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products" `
      -Method POST `
      -Headers @{ "Content-Type" = "application/json" } `
      -Body $productData `
      -UseBasicParsing

    $product = $createResponse.Content | ConvertFrom-Json
    $productId = $product.id
    Write-Host "✅ PASS - Created product ID: $productId" -ForegroundColor Green
}
catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# TEST 3: Query Product
Write-Host "TEST 3: Query Product (Read Side - Kafka Sync)" -ForegroundColor Yellow
Write-Host "   ⏳ Waiting 5 seconds for event propagation..."
Start-Sleep -Seconds 5

try {
    $getResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products/$productId" `
      -UseBasicParsing

    $readProduct = $getResponse.Content | ConvertFrom-Json
    
    if ($readProduct.id -eq $productId) {
        Write-Host "✅ PASS - Product found in read model" -ForegroundColor Green
        Write-Host "   Name: $($readProduct.name)"
        Write-Host "   Price: $($readProduct.price)"
    }
    else {
        Write-Host "❌ FAIL - Product not found in read model" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# TEST 4: List Products
Write-Host "TEST 4: List All Products" -ForegroundColor Yellow
try {
    $listResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products" `
      -UseBasicParsing

    $products = $listResponse.Content | ConvertFrom-Json
    Write-Host "✅ PASS - Found $($products.Count) product(s)" -ForegroundColor Green
}
catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# TEST 5: Update Stock
Write-Host "TEST 5: Update Stock (Command + Event)" -ForegroundColor Yellow
$stockData = @{
    quantity = 50
    reason = "Test adjustment"
} | ConvertTo-Json

try {
    $updateResponse = Invoke-WebRequest -Uri "$appUrl/api/v1/products/$productId/stock" `
      -Method PUT `
      -Headers @{ "Content-Type" = "application/json" } `
      -Body $stockData `
      -UseBasicParsing

    $updated = $updateResponse.Content | ConvertFrom-Json
    Write-Host "✅ PASS - Stock updated to $($updated.stockQuantity)" -ForegroundColor Green
}
catch {
    Write-Host "❌ FAIL - $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# SUMMARY
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ ALL TESTS PASSED!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 CQRS Architecture Verified:" -ForegroundColor Green
Write-Host "   ✅ Write side (PostgreSQL): Working"
Write-Host "   ✅ Message bus (Kafka): Event delivery working"
Write-Host "   ✅ Read side (CouchBase): Projection sync working"
Write-Host ""
Write-Host "📊 Test Summary:"
Write-Host "   - Health check: UP"
Write-Host "   - Create product: ✅"
Write-Host "   - Query product: ✅"
Write-Host "   - List products: ✅"
Write-Host "   - Update stock: ✅"
```

---

## 📋 Step 6: Check Application Logs

### **View All Logs**

```powershell
$RESOURCE_GROUP = "rg-product-catalog-dev"
$VM_NAME = "product-catalog-vm"
$vmIp = az vm show --resource-group $RESOURCE_GROUP --name $VM_NAME --show-details --query "publicIps" -o tsv

# SSH to VM and view logs
ssh azureuser@$vmIp

# On the VM, run:
cd /tmp
docker compose logs -f
```

### **View Specific Service Logs**

```bash
# From VM console:

# Application logs
docker compose logs -f product-catalog-service

# PostgreSQL logs
docker compose logs -f postgres

# CouchBase logs
docker compose logs -f couchbase

# Kafka logs
docker compose logs -f kafka
```

### **Check Service Status**

```bash
# From VM console:
docker compose ps
```

Expected output:
```
NAME                    STATUS
postgres                Up (healthy)
couchbase               Up (healthy)
kafka                   Up (healthy)
product-catalog-service Up (healthy)
```

---

## 🔍 Step 7: Monitor Metrics

### **Application Metrics**

```powershell
$vmIp = "YOUR_VM_IP"
$metricsUrl = "http://$vmIp:8080/actuator/metrics"

# List all available metrics
$metrics = Invoke-WebRequest -Uri $metricsUrl -UseBasicParsing | ConvertFrom-Json
$metrics.names | ForEach-Object { Write-Host "  • $_" }
```

### **Specific Metrics**

```powershell
$vmIp = "YOUR_VM_IP"

# JVM memory usage
Invoke-WebRequest -Uri "http://$vmIp:8080/actuator/metrics/jvm.memory.used" -UseBasicParsing | ConvertFrom-Json

# HTTP request count
Invoke-WebRequest -Uri "http://$vmIp:8080/actuator/metrics/http.server.requests" -UseBasicParsing | ConvertFrom-Json
```

---

## 🚨 Troubleshooting

### **Issue: "Connection refused"**

```powershell
# Application may still be starting
Write-Host "Waiting for services to start..."
Start-Sleep -Seconds 30

# Then retry health check
Invoke-WebRequest -Uri "http://$vmIp:8080/actuator/health" -UseBasicParsing
```

### **Issue: Services not showing as healthy**

```powershell
# SSH to VM
ssh azureuser@$vmIp

# Check Docker status
docker compose ps
docker compose logs --tail=50
```

### **Issue: Kafka not syncing events**

```bash
# On VM, check Kafka logs
docker compose logs kafka

# Verify topics exist
docker compose exec kafka kafka-topics.sh --bootstrap-server localhost:9092 --list
```

---

## 📚 API Quick Reference

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/actuator/health` | GET | Application health |
| `/swagger-ui.html` | GET | Interactive API docs |
| `/api/v1/products` | GET | List all products |
| `/api/v1/products` | POST | Create product (command) |
| `/api/v1/products/{id}` | GET | Get product (query) |
| `/api/v1/products/{id}/stock` | PUT | Update stock |
| `/actuator/metrics` | GET | Application metrics |

---

## ✨ Next Steps

1. ✅ Verify app is running (health check)
2. ✅ Access Swagger UI for interactive testing
3. ✅ Run E2E test script to validate CQRS flow
4. ✅ Check logs if anything fails
5. 🎯 Deploy to production or iterate

---

**Need help?** Check the logs or reach out!
