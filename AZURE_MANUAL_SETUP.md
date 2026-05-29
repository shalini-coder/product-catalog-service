# Manual Azure Setup — PostgreSQL, Couchbase, Kafka

This guide provides **step-by-step instructions** to manually create Azure managed services using the exact names and credentials configured in your Bicep templates.

## Configuration Summary

| Resource | Name | Username | Password |
|----------|------|----------|----------|
| **PostgreSQL** | `psql-product-catalog-dev` | `catalogadmin` | `<YOUR_PASSWORD>` |
| **Event Hubs** | `evhns-product-catalog-dev` | N/A | Generated |
| **Key Vault** | `kv-product-catalog-dev` | N/A | N/A |
| **Couchbase Capella** | Your choice | Your choice | `<YOUR_PASSWORD>` |
| **Resource Group** | `rg-product-catalog-poc` | N/A | N/A |
| **Region** | `centralindia` | N/A | N/A |
| **Environment** | `dev` | N/A | N/A |

---

## Step 1: Create PostgreSQL Flexible Server

### Via Azure Portal:

1. Go to: https://portal.azure.com/
2. Search for **"Azure Database for PostgreSQL flexible servers"**
3. Click **Create**
4. Fill in:
   - **Basics** tab:
     - Subscription: Your subscription
     - Resource group: `rg-product-catalog-poc`
     - Server name: `psql-product-catalog-dev`
     - Region: **Central India** (centralindia)
     - PostgreSQL version: **16**
     - Admin username: `catalogadmin`
     - Admin password: **<choose a strong password, e.g., `Postgres@Dev2024!`>**
     - Confirm password: (repeat)
   - **Compute + Storage** tab:
     - Compute tier: **Burstable**
     - Compute size: **Standard_B1ms** (1 vCore)
     - Storage: **32 GB**
   - **High Availability** tab:
     - HA Mode: **Not enabled** (for dev)
5. Click **Review + Create** → **Create**

### Via Azure CLI:

```bash
POSTGRES_PASSWORD="Postgres@Dev2024!"

az postgres flexible-server create \
  --resource-group rg-product-catalog-poc \
  --name psql-product-catalog-dev \
  --location centralindia \
  --admin-user catalogadmin \
  --admin-password "$POSTGRES_PASSWORD" \
  --sku-name Standard_B1ms \
  --storage-size 32 \
  --version 16 \
  --public-access 0.0.0.0 \
  --tier Burstable
```

### Create Database:

```bash
az postgres flexible-server db create \
  --resource-group rg-product-catalog-poc \
  --server-name psql-product-catalog-dev \
  --database-name productcatalog
```

### Get Connection String:

```bash
POSTGRES_FQDN=$(az postgres flexible-server show \
  --resource-group rg-product-catalog-poc \
  --name psql-product-catalog-dev \
  --query fullyQualifiedDomainName -o tsv)

echo "PostgreSQL FQDN: $POSTGRES_FQDN"
echo "SPRING_DATASOURCE_URL=jdbc:postgresql://${POSTGRES_FQDN}:5432/productcatalog"
echo "SPRING_DATASOURCE_USERNAME=catalogadmin"
echo "SPRING_DATASOURCE_PASSWORD=Postgres@Dev2024!"
```

**Save these values** — you'll need them later!

---

## Step 2: Create Azure Event Hubs (Kafka)

### Via Azure Portal:

1. Go to: https://portal.azure.com/
2. Search for **"Event Hubs"**
3. Click **Create namespace**
4. Fill in:
   - **Basics** tab:
     - Subscription: Your subscription
     - Resource group: `rg-product-catalog-poc`
     - Namespace name: `evhns-product-catalog-dev`
     - Location: **Central India**
     - Pricing tier: **Standard** (required for Kafka)
     - Throughput units: **1**
5. Go to **Advanced** tab:
   - Enable **Kafka**: ✅ Yes
6. Click **Review + Create** → **Create**

### Via Azure CLI:

```bash
az eventhubs namespace create \
  --resource-group rg-product-catalog-poc \
  --name evhns-product-catalog-dev \
  --location centralindia \
  --sku Standard \
  --capacity 1 \
  --enable-kafka true
```

### Create Event Hubs (Topics):

```bash
# Create multiple event hubs for different topics
az eventhubs eventhub create \
  --resource-group rg-product-catalog-poc \
  --namespace-name evhns-product-catalog-dev \
  --name product-added \
  --partition-count 3 \
  --message-retention 1

az eventhubs eventhub create \
  --resource-group rg-product-catalog-poc \
  --namespace-name evhns-product-catalog-dev \
  --name product-updated \
  --partition-count 3 \
  --message-retention 1

az eventhubs eventhub create \
  --resource-group rg-product-catalog-poc \
  --namespace-name evhns-product-catalog-dev \
  --name product-stock-changed \
  --partition-count 3 \
  --message-retention 1
```

### Create Authorization Policy:

```bash
az eventhubs namespace authorization-rule create \
  --resource-group rg-product-catalog-poc \
  --namespace-name evhns-product-catalog-dev \
  --name ProductCatalogPolicy \
  --rights Send Listen
```

### Get Connection String:

```bash
EVENTHUB_CONNECTION_STRING=$(az eventhubs namespace authorization-rule keys list \
  --resource-group rg-product-catalog-poc \
  --namespace-name evhns-product-catalog-dev \
  --name ProductCatalogPolicy \
  --query primaryConnectionString -o tsv)

echo "Event Hubs Connection String:"
echo "$EVENTHUB_CONNECTION_STRING"
```

**Save this** — needed for Kafka configuration!

---

## Step 3: Create Couchbase Capella Cluster

### Sign Up (Free):

1. Go to: https://cloud.couchbase.com/
2. Click **Sign Up** → Create account with email
3. Verify email

### Create Project:

1. Click **Projects** in left sidebar
2. Click **+ New Project**
3. Name: `product-catalog`
4. Click **Create**

### Create Cluster:

1. Click **+ Create Cluster** (in your project)
2. Fill in:
   - **Name**: `product-catalog-dev`
   - **Cloud Provider**: **Microsoft Azure**
   - **Region**: **Central India** (match Azure region)
   - **Service**: **Couchbase Capella** (default)
   - **Database Version**: **Latest**
   - **Node Type**: **Standard** (default for free tier)
   - **Nodes**: **3** (minimum for production-like setup)
3. Click **Create Cluster**

⏳ **Wait 5-10 minutes** for cluster to provision

### Create Bucket:

1. Once cluster is ready, click on it
2. Go to **Buckets** tab
3. Click **+ New Bucket**
4. Fill in:
   - **Name**: `product-catalog`
   - **Type**: **Couchbase**
   - **Memory quota**: **256 MB**
   - **Bucket durability**: **Minimal** (for dev)
5. Click **Create**

### Create Database User:

1. Go to **Security** tab
2. Click **Database Users**
3. Click **+ New User**
4. Fill in:
   - **Username**: `catalogadmin`
   - **Password**: **<choose password, e.g., `Couchbase@Dev2024!`>**
   - **Confirm password**: (repeat)
   - **Role**: Select **`Application User`**
   - **Buckets**: Select `product-catalog`
5. Click **Create User**

### Get Connection String:

1. Go to **Connect** tab
2. Under **Connectivity**, copy the **Couchbase Server** connection string
3. Should look like: `couchbases://cluster-xxxx.cloud.couchbase.com`

**Save this** — needed for Spring config!

---

## Step 4: Create Azure Key Vault

### Via Azure Portal:

1. Go to: https://portal.azure.com/
2. Search for **"Key Vault"**
3. Click **Create**
4. Fill in:
   - **Basics** tab:
     - Subscription: Your subscription
     - Resource group: `rg-product-catalog-poc`
     - Key Vault name: `kv-product-catalog-dev`
     - Region: **Central India**
     - Pricing tier: **Standard**
5. Go to **Access configuration** tab:
   - Permission model: **Vault access policy**
6. Click **Review + Create** → **Create**

### Via Azure CLI:

```bash
az keyvault create \
  --resource-group rg-product-catalog-poc \
  --name kv-product-catalog-dev \
  --location centralindia \
  --enable-rbac-authorization false
```

### Add Secrets to Key Vault:

```bash
# PostgreSQL password
az keyvault secret set \
  --vault-name kv-product-catalog-dev \
  --name spring-datasource-password \
  --value "Postgres@Dev2024!"

# Couchbase password
az keyvault secret set \
  --vault-name kv-product-catalog-dev \
  --name spring-couchbase-password \
  --value "Couchbase@Dev2024!"

# Couchbase connection string
az keyvault secret set \
  --vault-name kv-product-catalog-dev \
  --name spring-couchbase-connection-string \
  --value "couchbases://cluster-xxxx.cloud.couchbase.com"

# Couchbase username
az keyvault secret set \
  --vault-name kv-product-catalog-dev \
  --name spring-couchbase-username \
  --value "catalogadmin"

# JWT Secret (must be at least 64 characters)
JWT_SECRET="your-super-secret-jwt-key-must-be-at-least-64-characters-long-please!"
az keyvault secret set \
  --vault-name kv-product-catalog-dev \
  --name app-jwt-secret \
  --value "$JWT_SECRET"

# Event Hubs connection string
az keyvault secret set \
  --vault-name kv-product-catalog-dev \
  --name azure-eventhub-connection-string \
  --value "$EVENTHUB_CONNECTION_STRING"
```

---

## Step 5: Gather All Connection Strings

Create a file `.env.azure` with all values (for reference):

```bash
# PostgreSQL
SPRING_DATASOURCE_URL=jdbc:postgresql://psql-product-catalog-dev.postgres.database.azure.com:5432/productcatalog
SPRING_DATASOURCE_USERNAME=catalogadmin
SPRING_DATASOURCE_PASSWORD=Postgres@Dev2024!

# Couchbase Capella
SPRING_COUCHBASE_CONNECTION_STRING=couchbases://cluster-xxxx.cloud.couchbase.com
SPRING_COUCHBASE_USERNAME=catalogadmin
SPRING_COUCHBASE_PASSWORD=Couchbase@Dev2024!
SPRING_COUCHBASE_BUCKET_NAME=product-catalog

# Event Hubs (Kafka)
SPRING_KAFKA_BOOTSTRAP_SERVERS=evhns-product-catalog-dev.servicebus.windows.net:9093
AZURE_EVENTHUB_CONNECTION_STRING=<from-keyvault>
AZURE_EVENTHUB_NAMESPACE=evhns-product-catalog-dev

# JWT & Key Vault
APP_JWT_SECRET=<from-keyvault>
AZURE_KEYVAULT_ENDPOINT=https://kv-product-catalog-dev.vault.azure.net/

# Resource Info
AZURE_RESOURCE_GROUP=rg-product-catalog-poc
AZURE_REGION=centralindia
```

---

## Step 6: Add Secrets to GitHub

Go to: https://github.com/shalini-coder/product-catalog-service/settings/secrets/actions

Click **New repository secret** and add:

| Secret Name | Value |
|-------------|-------|
| `POSTGRES_ADMIN_PASSWORD` | `Postgres@Dev2024!` |
| `COUCHBASE_PASSWORD` | `Couchbase@Dev2024!` |
| `COUCHBASE_CONNECTION_STRING` | `couchbases://cluster-xxxx.cloud.couchbase.com` |
| `COUCHBASE_USERNAME` | `catalogadmin` |
| `APP_JWT_SECRET` | Your JWT secret (64+ chars) |

---

## Step 7: Verify All Resources

```bash
# Check PostgreSQL
az postgres flexible-server show \
  --resource-group rg-product-catalog-poc \
  --name psql-product-catalog-dev \
  --query '{Name: name, Fqdn: fullyQualifiedDomainName, Status: state}'

# Check Event Hubs
az eventhubs namespace show \
  --resource-group rg-product-catalog-poc \
  --name evhns-product-catalog-dev \
  --query '{Name: name, Kafka: kafkaEnabled}'

# Check Key Vault
az keyvault show \
  --resource-group rg-product-catalog-poc \
  --name kv-product-catalog-dev \
  --query '{Name: name, VaultUri: properties.vaultUri}'

# List Key Vault secrets
az keyvault secret list \
  --vault-name kv-product-catalog-dev \
  --query '[].name'
```

---

## ✅ Ready for Deployment!

Once all resources are created and secrets are added to GitHub, you can:

```bash
# Trigger the workflow with managed-services mode
gh workflow run azure-deploy.yml \
  -f environment=dev \
  -f deployment_mode=managed-services
```

Or manually deploy the Bicep:

```bash
az deployment group create \
  --resource-group rg-product-catalog-poc \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.bicepparam \
  --parameters \
    deploymentMode="managed-services" \
    postgresAdminPassword="Postgres@Dev2024!" \
    couchbasePassword="Couchbase@Dev2024!" \
    couchbaseConnectionString="couchbases://cluster-xxxx.cloud.couchbase.com" \
    couchbaseUsername="catalogadmin" \
    jwtSecret="your-jwt-secret"
```

---

## Troubleshooting

**PostgreSQL connection refused?**
- Wait 2-3 minutes after creation
- Check firewall rule allows Azure services

**Couchbase Capella cluster stuck in provisioning?**
- Wait 10-15 minutes
- Check if you have free tier limits

**Event Hubs Kafka not accessible?**
- Verify `kafkaEnabled: true` is set
- Use port `9093` for SASL_SSL connections

---

**Questions?** Refer to [AZURE_MANAGED_SERVICES.md](AZURE_MANAGED_SERVICES.md) for more details.
