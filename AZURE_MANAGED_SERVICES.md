# Deploying to Azure with Managed Services

This guide explains how to deploy the Product Catalog Service using **Azure Managed Services** instead of containerized databases.

## Overview

### Docker-Only Mode (Current)
- PostgreSQL, Couchbase, Kafka run as **containers** in Azure Container Apps Environment
- Lower initial cost, but higher operational complexity
- Good for dev/testing

### Managed Services Mode (Recommended for Production)
- **Azure Database for PostgreSQL Flexible Server** — fully managed relational database
- **Couchbase Capella** — managed Couchbase cloud service (requires manual setup)
- **Azure Event Hubs** — Kafka-compatible event streaming service
- **Azure Key Vault** — secrets management
- Better scalability, automatic backups, monitoring

## Prerequisites

1. **Azure CLI** installed: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
2. **Azure Subscription** with sufficient quota
3. **GitHub Secrets** configured (see [main README](README.md))
4. **Couchbase Capella Account** (free tier available at https://cloud.couchbase.com/)

## Step 1: Create Couchbase Capella Cluster

Since Couchbase Capella is not an Azure service, it must be created separately:

1. Sign up at https://cloud.couchbase.com/
2. Create a **new project** (e.g., "product-catalog")
3. Create a **cluster**:
   - Name: `product-catalog-prod` (or your preference)
   - Cloud: **Azure**
   - Region: **Same as your Azure RG** (centralindia, eastus, etc.)
   - Service: **Couchbase Capella**
4. Once provisioned, create a **bucket**:
   - Name: `product-catalog`
   - Type: `Couchbase`
   - Memory quota: 256 MB (minimum)
5. Create a **database user**:
   - Username: `catalogadmin` (or your choice)
   - Password: (save this — you'll need it)
   - Role: `Application User`
6. Get the **connection string**:
   - Navigate to **Connect** in the cluster overview
   - Copy the "Couchbase Server" connection string (looks like `couchbases://cluster-xxxx.cloud.couchbase.com`)

## Step 2: Gather Azure Connection Strings

### PostgreSQL Flexible Server
After deployment, retrieve the FQDN:
```bash
az postgres flexible-server show \
  --resource-group rg-product-catalog-poc \
  --name psql-product-catalog-dev \
  --query fullyQualifiedDomainName -o tsv
```

### Event Hubs
```bash
az eventhubs namespace authorization-rule keys list \
  --resource-group rg-product-catalog-poc \
  --namespace-name evhns-product-catalog-dev \
  --name ProductCatalogPolicy \
  --query primaryConnectionString -o tsv
```

## Step 3: Store Secrets in GitHub

Add these secrets to your GitHub repository (Settings → Secrets):

| Secret Name | Value |
|-------------|-------|
| `COUCHBASE_CONNECTION_STRING` | `couchbases://cluster-xxxx.cloud.couchbase.com` |
| `COUCHBASE_USERNAME` | Your Capella username (e.g., `catalogadmin`) |
| `COUCHBASE_PASSWORD` | Your Capella password |
| `POSTGRES_ADMIN_PASSWORD` | PostgreSQL admin password (auto-generated or your choice) |
| `APP_JWT_SECRET` | Your JWT secret (min 64 chars) |

## Step 4: Deploy to Azure

### Option A: Manual Deployment

```bash
# Set your environment variables
export RESOURCE_GROUP="rg-product-catalog-poc"
export COUCHBASE_CONNECTION_STRING="couchbases://cluster-xxxx.cloud.couchbase.com"
export COUCHBASE_USERNAME="catalogadmin"
export COUCHBASE_PASSWORD="your-capella-password"
export POSTGRES_ADMIN_PASSWORD="postgres-admin-pwd"
export APP_JWT_SECRET="your-jwt-secret-min-64-chars"

# Deploy infrastructure
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.bicepparam \
  --parameters \
    deploymentMode="managed-services" \
    jwtSecret="$APP_JWT_SECRET" \
    postgresAdminPassword="$POSTGRES_ADMIN_PASSWORD" \
    couchbasePassword="$COUCHBASE_PASSWORD" \
    couchbaseConnectionString="$COUCHBASE_CONNECTION_STRING" \
    couchbaseUsername="$COUCHBASE_USERNAME"
```

### Option B: GitHub Actions

Trigger the workflow manually:

```bash
gh workflow run azure-deploy.yml \
  -f environment=dev \
  -f deployment_mode=managed-services
```

Or push a commit and the workflow will run automatically.

## Step 5: Verify Deployment

### Check if resources were created

```bash
# PostgreSQL
az postgres flexible-server show \
  --resource-group rg-product-catalog-poc \
  --name psql-product-catalog-dev

# Event Hubs
az eventhubs namespace show \
  --resource-group rg-product-catalog-poc \
  --name evhns-product-catalog-dev

# Key Vault
az keyvault show \
  --resource-group rg-product-catalog-poc \
  --name kv-product-catalog-dev
```

### Access the Application

Once the Container App is deployed:

```bash
# Get the FQDN
az containerapp show \
  --resource-group rg-product-catalog-poc \
  --name ca-product-catalog-dev \
  --query properties.configuration.ingress.fqdn -o tsv
```

Then access: `https://<fqdn>/swagger-ui/index.html`

## Environment Variables Reference

The application (in `prod` profile) expects these environment variables:

```yaml
# Database
SPRING_DATASOURCE_URL: jdbc:postgresql://<postgres-fqdn>:5432/productcatalog
SPRING_DATASOURCE_USERNAME: catalogadmin
SPRING_DATASOURCE_PASSWORD: (from Key Vault)

# Couchbase Capella
SPRING_COUCHBASE_CONNECTION_STRING: couchbases://cluster-xxxx.cloud.couchbase.com
SPRING_COUCHBASE_USERNAME: catalogadmin
SPRING_COUCHBASE_PASSWORD: (from Key Vault)
SPRING_COUCHBASE_BUCKET_NAME: product-catalog

# Event Hubs (Kafka)
SPRING_KAFKA_BOOTSTRAP_SERVERS: <namespace>.servicebus.windows.net:9093
SPRING_KAFKA_SECURITY_PROTOCOL: SASL_SSL
SPRING_KAFKA_SASL_MECHANISM: PLAIN
SPRING_KAFKA_SASL_JAAS_CONFIG: org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="<connection-string>";

# JWT & Monitoring
APP_JWT_SECRET: (from Key Vault)
AZURE_KEYVAULT_ENDPOINT: https://<vault-name>.vault.azure.net/
AZURE_APPINSIGHTS_CONNECTION_STRING: (auto-set by App Insights)
```

## Cost Estimation (Monthly)

| Service | Tier | Estimated Cost |
|---------|------|-----------------|
| PostgreSQL Flexible Server | Standard_B1ms | ~$30-50 |
| Couchbase Capella | Developer (free) or Pro | $0 (free) or $150+ |
| Event Hubs | Standard, 1 capacity | ~$100-150 |
| Key Vault | Standard | ~$0.34 |
| Container Apps | 0.5 CPU, 1Gi RAM | ~$20-30 |
| Application Insights | Pay-as-you-go | ~$5-20 |
| **Total** | | **~$155-250/month** |

**Note:** Couchbase Capella free tier is limited. For production, upgrade to Pro tier.

## Troubleshooting

### Can't connect to Couchbase Capella
- Verify connection string is correct: `couchbases://` (with 's')
- Check Capella firewall rules allow traffic from Azure region
- Ensure bucket exists and user has correct permissions

### PostgreSQL connection timeout
- Check firewall rule `AllowAllAzureServicesAndResourcesWithinAzureIps` exists
- Verify Container App is in the same VNET (or publicly accessible)

### Event Hubs authentication fails
- Verify the `$ConnectionString` format in SASL config
- Check connection string has `SharedAccessKeyName=` and `SharedAccessKey=`

### Key Vault secrets not resolved
- Container App must have managed identity with Key Vault RBAC access
- Wait a few minutes for RBAC propagation

## Switching Back to Docker-Only

To revert to containerized databases:

```bash
az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/dev.bicepparam \
  --parameters deploymentMode="docker-only"
```

This will **NOT** delete existing managed services. Delete them manually if needed.

## References

- [Azure Database for PostgreSQL](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Couchbase Capella](https://docs.couchbase.com/cloud/get-started/start-here.html)
- [Azure Event Hubs](https://docs.microsoft.com/en-us/azure/event-hubs/)
- [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/)
