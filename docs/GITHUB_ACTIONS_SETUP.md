# GitHub Actions Deployment Setup

## Prerequisites

1. **GitHub Repository** - Code pushed to GitHub
2. **Azure Subscription** - Active Azure subscription
3. **Service Principal** - For Azure authentication

---

## Step 1: Create Azure Service Principal

Run this in PowerShell/Bash:

```powershell
$subscriptionId = "c6f59f79-004f-45ab-b608-1e2c65cdee15"

# Create service principal
$sp = az ad sp create-for-rbac `
  --name "github-actions-product-catalog" `
  --role "Contributor" `
  --scopes "/subscriptions/$subscriptionId" `
  --output json | ConvertFrom-Json

# Display credentials (save these!)
Write-Host $sp | ConvertTo-Json
```

This will output JSON like:
```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "subscriptionId": "c6f59f79-004f-45ab-b608-1e2c65cdee15",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

---

## Step 2: Add GitHub Secrets

In GitHub repository:
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add:

| Secret Name | Value |
|------------|-------|
| `AZURE_CREDENTIALS` | Full JSON output from Step 1 |
| `AZURE_SUBSCRIPTION_ID` | `c6f59f79-004f-45ab-b608-1e2c65cdee15` |

**Example for AZURE_CREDENTIALS:**
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "..."
}
```

---

## Step 3: Push Code to GitHub

```bash
git add .github/workflows/deploy-container-apps-kraft.yml
git add infra/bicep/container-apps-kraft.bicep
git add infra/bicep/parameters/container-apps-kraft-dev.bicepparam
git commit -m "Add Container Apps KRaft deployment via GitHub Actions"
git push origin main
```

---

## Step 4: Run the Workflow

### Option A: Manual Trigger (Recommended for Testing)

1. Go to GitHub repo → **Actions** tab
2. Select **"Deploy Container Apps with KRaft"** workflow
3. Click **"Run workflow"**
4. Select:
   - Environment: `dev`
   - Location: `canadacentral`
5. Click **"Run workflow"**

### Option B: Automatic Trigger (After Merge to Main)

Modify the workflow to trigger automatically:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'infra/bicep/**'
      - '.github/workflows/deploy-container-apps-kraft.yml'
```

---

## Step 5: Monitor Deployment

1. Go to **Actions** tab
2. Click on the running workflow
3. Watch the logs in real-time

Output will show:
- ✅ Template validation passed
- ✅ Deployment completed
- 🌐 Application URL
- 📊 Kafka UI URL

---

## Step 6: Test the Deployment

Once workflow completes (5-10 minutes):

```bash
# Health check
curl https://<app-url>/actuator/health

# Login
curl -X POST https://<app-url>/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"changeme"}'

# Create product
curl -X POST https://<app-url>/api/v1/products \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "description": "Testing via GitHub Actions",
    "price": 99.99,
    "stockQuantity": 10,
    "tags": ["github", "actions", "kraft"]
  }'

# Query products
curl -X GET "https://<app-url>/api/v1/products" \
  -H "Authorization: Bearer <token>"
```

---

## Troubleshooting

### Workflow fails with "Subscription not found"
- Verify `AZURE_SUBSCRIPTION_ID` secret is correct
- Check subscription ID: `az account show --query id`

### "Resource group creation failed"
- Verify service principal has `Contributor` role
- Check if resource group already exists

### "Bicep validation failed"
- Verify template file exists: `infra/bicep/container-apps-kraft.bicep`
- Check parameter file: `infra/bicep/parameters/container-apps-kraft-dev.bicepparam`

### App not healthy after deployment
- Wait 5 minutes (containers still starting)
- Check Container Apps logs: `az containerapp logs show -n ca-app-product-catalog-dev -g rg-product-catalog-poc`

---

## Cleanup

To delete all deployed resources:

```bash
az group delete --name rg-product-catalog-poc --yes
```

Or in GitHub Actions workflow file, create a separate cleanup workflow with:

```yaml
on:
  workflow_dispatch:

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          az group delete --name rg-product-catalog-poc --yes
          echo "✅ Resource group deleted"
```

---

## What Gets Deployed

| Component | Service | Status |
|-----------|---------|--------|
| Database (write) | PostgreSQL Container App | ✅ |
| Event Streaming | Kafka with KRaft | ✅ |
| Database (read) | Couchbase Container App | ✅ |
| Monitoring | Kafka UI | ✅ |
| Application | Spring Boot App | ✅ |

---

## Useful Commands

```bash
# View deployment status
az deployment group show \
  --resource-group rg-product-catalog-poc \
  --name container-apps-kraft

# Check Container App logs
az containerapp logs show \
  --name ca-app-product-catalog-dev \
  --resource-group rg-product-catalog-poc

# Restart a container app
az containerapp revision restart \
  --name ca-app-product-catalog-dev \
  --resource-group rg-product-catalog-poc

# Get app URL
az containerapp show \
  --name ca-app-product-catalog-dev \
  --resource-group rg-product-catalog-poc \
  --query properties.configuration.ingress.fqdn -o tsv
```
