# Azure Deployment Guide — Product Catalog Service

## Do you HAVE to use Azure-managed Postgres and Couchbase?

**No. You have two completely valid paths:**

| | Path A: All Docker on Azure | Path B: Managed Azure Services |
|---|---|---|
| **Postgres** | Docker container (`postgres:16-alpine`) | Azure Database for PostgreSQL Flexible Server |
| **Couchbase** | Docker container (`couchbase:community-7.2.0`) | Couchbase Capella (Azure Marketplace) |
| **Kafka** | Bitnami Kafka container (KRaft, no Zookeeper) | Azure Event Hubs (Kafka-compatible) |
| **Complexity** | ⭐ Simplest — same as local dev | ⭐⭐⭐ More setup |
| **Cost (dev)** | Lower (only Container Apps compute) | Higher (managed services have base cost) |
| **Operations** | You manage backups, HA, scaling | Azure manages it |
| **Best for** | Dev / staging / prototyping | Production workloads |

**Recommendation:** Start with Path A (all Docker). Migrate individual services to managed when you need production-grade HA or automated backups.

---

## Path A — All Docker Containers on Azure (Recommended Start)

Everything runs as Docker containers inside Azure Container Apps — identical to your local `docker-compose.yml`.

### Step 1: Create Azure resources

```bash
# Login
az login

# Create resource group
az group create --name rg-product-catalog-dev --location eastus

# Deploy infrastructure (creates ACR + Container Apps Environment only)
az deployment group create \
  --resource-group rg-product-catalog-dev \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.bicepparam \
  --parameters jwtSecret="$(openssl rand -base64 48)"
```

### Step 2: Build and push the app image

```bash
ACR_NAME=$(az deployment group show \
  --resource-group rg-product-catalog-dev \
  --name main \
  --query "properties.outputs.acrLoginServer.value" -o tsv)

az acr login --name $ACR_NAME

docker build -t $ACR_NAME/product-catalog-service:latest .
docker push $ACR_NAME/product-catalog-service:latest
```

### Step 3: Deploy the full stack

```bash
# Replace ACR_LOGIN_SERVER and secrets with real values
export ACR_LOGIN_SERVER="<acr-name>.azurecr.io"
export IMAGE_TAG="latest"
export POSTGRES_PASSWORD="<choose-strong-password>"
export COUCHBASE_PASSWORD="<choose-strong-password>"
export APP_JWT_SECRET="<64+-char-random-string>"

az containerapp compose create \
  --environment acaenv-product-catalog-dev \
  --resource-group rg-product-catalog-dev \
  --compose-file-path docker-compose.azure-aca.yml
```

### That's it — all services run as Docker containers on Azure. ✅

---

## Path B — Managed Azure Services

Use this when you need automated backups, Azure SLA, and built-in HA.

### PostgreSQL → Azure Database for PostgreSQL Flexible Server

#### Deploy via Bicep
```bash
az deployment group create \
  --resource-group rg-product-catalog-prod \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/prod.bicepparam \
  --parameters \
    jwtSecret="$JWT_SECRET" \
    postgresAdminPassword="$PG_PASSWORD" \
    deploymentMode="managed-services"
```

#### Allow your local machine to connect
1. Azure Portal → Your PostgreSQL server → **Networking**
2. Click **Add current client IP address**
3. Save

#### Connection string for local development
```
SPRING_PROFILES_ACTIVE=local-azure
AZURE_POSTGRES_HOST=<server-name>
AZURE_POSTGRES_USER=catalogadmin
AZURE_POSTGRES_PASSWORD=<password>
```

The app will connect using:
```
jdbc:postgresql://<server-name>.postgres.database.azure.com:5432/productcatalog?sslmode=require
```
SSL is **mandatory** on Azure PostgreSQL — the `?sslmode=require` parameter handles it.

---

### Couchbase → Couchbase Capella (Azure)

Couchbase doesn't have a native Azure managed service, but **Couchbase Capella** is Couchbase's own cloud service that runs on Azure regions.

#### Sign up and create a cluster
1. Go to https://cloud.couchbase.com → **Sign Up Free**
2. Create Organization → **Create Cluster**
3. Choose **Azure** as provider, select your region (e.g., East US)
4. Choose **Free tier** for dev or **Developer Pro** for production

#### Allow connections
In Capella: **Cluster → Settings → Allowed IPs**
- For Azure Container Apps: add the outbound IP range of your ACA environment
  ```bash
  az containerapp env show \
    --name acaenv-product-catalog-dev \
    --resource-group rg-product-catalog-dev \
    --query "properties.staticIp"
  ```
- For local development: add your public IP (https://whatismyip.com)

#### Create database credentials
Capella: **Cluster → Security → Database Access** → Add User

#### Connection config
```yaml
spring:
  couchbase:
    connection-string: couchbases://<cluster-id>.dp.cloud.couchbase.com   # note: couchbases:// with TLS
    username: <db-user>
    password: <db-password>
  data:
    couchbase:
      bucket-name: product-catalog
```

#### Create the bucket
Capella: **Cluster → Buckets** → **Add Bucket** → Name: `product-catalog`

---

### Kafka → Azure Event Hubs

Deployed automatically by Bicep (`managed-services` mode). Event Hubs uses exactly the same Kafka client — only the connection config changes:

```yaml
spring:
  kafka:
    bootstrap-servers: <namespace>.servicebus.windows.net:9093
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: PLAIN
      sasl.jaas.config: >-
        org.apache.kafka.common.security.plain.PlainLoginModule required
        username="$ConnectionString"
        password="<connection-string>";
```

**Important:** Event Hub names cannot contain dots. The Bicep module creates Event Hubs named `product-added`, `product-updated`, etc. (dots replaced with hyphens). The `KafkaTopics` constants still use dots — Event Hubs maps them automatically.

---

## Connecting to Azure Services from Your Local Machine

Use the `local-azure` Spring profile. This lets you run the app on your laptop while it talks to real Azure services — great for debugging production issues.

### Step 1: Fill in environment variables
```bash
cp .env.azure.example .env.azure.local
# Edit .env.azure.local with your real Azure credentials
```

### Step 2: Load and run
```powershell
# PowerShell — load .env.azure.local into environment
Get-Content .env.azure.local |
  Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' } |
  ForEach-Object {
    $name, $value = $_ -split '=', 2
    Set-Item "env:$name" $value
  }

# Run the app
./mvnw spring-boot:run -Dspring-boot.run.profiles=local-azure
```

Or with Docker (only the app container, no local DB):
```powershell
docker compose -f docker-compose.local-azure.yml --env-file .env.azure.local up
```

### Firewall rules checklist

| Service | Where to add your IP |
|---|---|
| Azure PostgreSQL | Portal → Server → Networking → Add client IP |
| Couchbase Capella | Capella UI → Cluster → Settings → Allowed IPs |
| Azure Event Hubs | No IP restriction — uses connection string auth |

---

## GitHub Actions Secrets Required

Add these in: GitHub → Settings → Secrets and variables → Actions

| Secret | Value |
|---|---|
| `AZURE_CREDENTIALS` | Output of `az ad sp create-for-rbac --sdk-auth` |
| `AZURE_RESOURCE_GROUP` | `rg-product-catalog-dev` |
| `ACR_NAME` | Your ACR name (without `.azurecr.io`) |
| `APP_JWT_SECRET` | 64+ char random string |
| `POSTGRES_ADMIN_PASSWORD` | Strong password (managed-services only) |
| `COUCHBASE_PASSWORD` | Capella database user password (managed-services only) |

### Create the service principal
```bash
az ad sp create-for-rbac \
  --name "sp-product-catalog-deploy" \
  --role contributor \
  --scopes /subscriptions/<sub-id>/resourceGroups/rg-product-catalog-dev \
  --sdk-auth
```
Copy the full JSON output as the `AZURE_CREDENTIALS` secret.

---

## Quick Reference: Which docker-compose file to use?

| Situation | File |
|---|---|
| Local development (everything local) | `docker-compose.yml` |
| Local app, Azure DB + Couchbase + Event Hubs | `docker-compose.local-azure.yml` |
| Full stack as Docker on Azure Container Apps | `docker-compose.azure-aca.yml` |
| Production with managed Azure services | Bicep + `application-azure.yml` |

---

## Summary: What changes between local and Azure

The **application code is identical** in all scenarios. Only the Spring profile and environment variables change:

```
Local dev        →  SPRING_PROFILES_ACTIVE=default       (docker-compose.yml)
Local → Azure    →  SPRING_PROFILES_ACTIVE=local-azure   (your machine, Azure backends)
Docker on Azure  →  SPRING_PROFILES_ACTIVE=prod          (docker-compose.azure-aca.yml)
Managed services →  SPRING_PROFILES_ACTIVE=azure         (Bicep managed-services mode)
```
