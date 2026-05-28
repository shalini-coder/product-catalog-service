# POC Quickstart — Zero Local Install

**No Azure CLI to install. No Docker build on your machine.**  
Everything runs in your browser via Azure Cloud Shell.

---

## What you need on your laptop

| Tool | Used for | Already installed? |
|------|----------|--------------------|
| `git` | Push code to GitHub | Usually yes on dev machines |
| A browser | Azure Cloud Shell + Swagger testing | Yes |
| Nothing else | — | — |

---

## Step 0 — Push your code to GitHub

Azure Cloud Shell will clone your repo and build the Docker image **in Azure** — no local disk space needed.

```powershell
# In your project folder (PowerShell or Git Bash)
git init
git add .
git commit -m "POC initial commit"
```

Go to **https://github.com/new** → create a free private repo → then:

```powershell
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

---

## Step 1 — Open Azure Cloud Shell

Go to **https://shell.azure.com** in your browser.

- Sign in with your Azure account (free trial: https://azure.microsoft.com/free)
- Choose **Bash** when asked
- First launch asks to create a storage account — click **Create** (~$0.02/month)

> **Azure Cloud Shell already has:** `az` CLI, `git`, `docker`, `curl` — nothing to install on your machine.

---

## Step 2 — Clone and deploy (inside Cloud Shell)

Paste these two commands in the Cloud Shell terminal:

```bash
# Clone your GitHub repo
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>

# One command deploys everything
bash scripts/deploy-poc-cloudshell.sh
```

**What the script does automatically:**

```
[1/6]  Creates Resource Group
[2/6]  Creates Azure Container Registry (ACR)
[3/6]  Builds Docker image IN Azure  ←  az acr build, no local Docker needed
[4/6]  Creates Container Apps Environment
[5/6]  Deploys: postgres + couchbase + kafka + app  (all as Docker containers)
[6/6]  Prints your public URL
```

First run takes **~8-10 minutes** (Azure downloads and builds images in the cloud).

---

## Step 3 — Test the CQRS flow (Swagger UI)

The script prints a URL like:
```
Swagger UI : https://app.nicemeadow-abc123.eastus.azurecontainerapps.io/swagger-ui/index.html
```

Open it in your browser and run this sequence to see CQRS working end-to-end:

#### ① Create a product  →  written to PostgreSQL (write side)
```
POST /api/v1/products
{
  "name": "Gaming Laptop",
  "description": "High performance",
  "price": 1299.99
}
→ 201 Created   Location: /api/v1/products/{uuid}
```

#### ② Wait ~2 seconds  →  Kafka carries the event to Couchbase

#### ③ Read the product  →  served from Couchbase (read side, not PostgreSQL)
```
GET /api/v1/products/{uuid}
→ 200 OK   { "name": "Gaming Laptop", "inStock": false, ... }
```

#### ④ Add stock
```
POST /api/v1/products/{uuid}/stock?quantity=50
→ 200 OK
```

#### ⑤ Search (hits Couchbase)
```
GET /api/v1/products/search?name=Gaming
→ 200 OK   [ { "name": "Gaming Laptop", "inStock": true, ... } ]
```

---

## What's happening inside (CQRS flow)

```
Your Request (Swagger UI)
        │
        ▼
   ProductController
        │
   ┌────┴──────────────────────────────┐
   │ WRITE (POST/PUT/DELETE)           │ READ (GET)
   ▼                                   ▼
ProductCommandHandler         ProductQueryHandler
        │                              │
        ▼                              ▼
  ProductAggregate              ProductProjection
  (domain logic)                (Couchbase doc)
        │
        ▼
   PostgreSQL ──► OutboxPoller ──► Kafka ──► ProductEventConsumer ──► Couchbase
  (write store)    (every 5s)              (async, updates projection) (read store)
```

- **POST** → hits `ProductCommandHandler` → saves to PostgreSQL → writes to outbox
- **Outbox poller** fires every 5s → publishes event to Kafka
- **ProductEventConsumer** listens → creates/updates Couchbase projection
- **GET** → hits `ProductQueryHandler` → reads **only from Couchbase**, never PostgreSQL

---

## Watch it live

Open a second Cloud Shell tab and run:

```bash
# Follow application logs in real time
az containerapp logs show \
  --name app \
  --resource-group rg-product-catalog-poc \
  --follow

# See all containers and their status
az containerapp list \
  --resource-group rg-product-catalog-poc \
  --output table
```

---

## Tear down — stops all billing

```bash
# In Cloud Shell
az group delete --name rg-product-catalog-poc --yes --no-wait
```

Deletes everything. Nothing left running, no costs.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `GET` returns 404 right after `POST` | Event hasn't reached Couchbase yet | Wait 2-3 seconds and retry |
| `401 Unauthorized` on POST/PUT | JWT required for write ops | See note below |
| Couchbase bucket error in logs | Init container still running | Wait 30s — `couchbase-init` bootstraps the bucket |
| Script fails at `az acr build` | Not in repo root | `cd <your-repo>` before running script |

### Quick fix for 401 on write endpoints (POC only)
In `ProductController.java`, temporarily remove `@PreAuthorize("hasRole('ADMIN')")` 
from the methods you want to test, commit, push to GitHub, and re-run the deploy script.
The new image rebuilds in Azure automatically.
