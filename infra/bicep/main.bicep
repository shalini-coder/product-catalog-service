// ─────────────────────────────────────────────────────────────────────────────
// main.bicep  —  Product Catalog Service  —  Azure Infrastructure
//
// Deploys two topology options (controlled by `deploymentMode` param):
//
//   "docker-only"    — Container Apps Environment + ACR only.
//                      Postgres, Couchbase, Kafka run as containers inside ACA.
//                      Simplest, lowest cost, mirrors local docker-compose.
//
//   "managed-services" — Full managed: Azure PostgreSQL Flexible Server +
//                        Azure Event Hubs + Key Vault + App Insights.
//                        Couchbase Capella must be set up manually (see AZURE_SETUP.md).
//
// Deploy:
//   az deployment group create \
//     --resource-group rg-product-catalog \
//     --template-file infra/bicep/main.bicep \
//     --parameters infra/bicep/parameters/dev.bicepparam
// ─────────────────────────────────────────────────────────────────────────────

targetScope = 'resourceGroup'

// ── Parameters ───────────────────────────────────────────────────────────────

@description('Deployment mode: "docker-only" or "managed-services"')
@allowed(['docker-only', 'managed-services'])
param deploymentMode string = 'docker-only'

@description('Environment suffix: dev, staging, prod')
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Name prefix for all resources')
param appName string = 'product-catalog'

@description('Name of an existing ACR to use. If empty, a new ACR is created.')
param existingAcrName string = ''

@description('PostgreSQL administrator login (managed-services only)')
param postgresAdminLogin string = 'catalogadmin'

@secure()
@description('PostgreSQL administrator password (managed-services only)')
param postgresAdminPassword string = ''

@secure()
@description('JWT secret (at least 64 chars)')
param jwtSecret string

@secure()
@description('Couchbase password (Capella or local)')
param couchbasePassword string = ''

@description('Couchbase Capella connection string (managed-services only)')
param couchbaseConnectionString string = ''

@description('Couchbase Capella username (managed-services only)')
param couchbaseUsername string = ''

// ── Variables ─────────────────────────────────────────────────────────────────

var suffix        = '${appName}-${environment}'
var generatedAcrName = replace('acr${appName}${environment}', '-', '')
var resolvedAcrName  = empty(existingAcrName) ? generatedAcrName : existingAcrName
var acaEnvName    = 'acaenv-${suffix}'
var appInsName    = 'appi-${suffix}'
var kvName        = 'kv-${suffix}'

// ── Azure Container Registry ──────────────────────────────────────────────────
// Creates a new ACR when existingAcrName is empty; otherwise references the existing one.

resource newAcr 'Microsoft.ContainerRegistry/registries@2023-07-01' = if (empty(existingAcrName)) {
  name: generatedAcrName
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: true }
}

resource existingAcr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = if (!empty(existingAcrName)) {
  name: existingAcrName
}

// ── Container Apps Managed Environment ───────────────────────────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${suffix}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: acaEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ── Application Insights (both modes) ─────────────────────────────────────────

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ── DOCKER-ONLY mode resources (container apps for Postgres, Couchbase, Kafka) ──

// PostgreSQL container app
resource postgresApp 'Microsoft.App/containerApps@2023-05-01' = if (deploymentMode == 'docker-only') {
  name: 'ca-postgres-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: acaEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 5432
      }
    }
    template: {
      containers: [
        {
          name: 'postgres'
          image: 'postgres:16-alpine'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'POSTGRES_USER'
              value: 'postgres'
            }
            {
              name: 'POSTGRES_PASSWORD'
              value: 'postgres'
            }
            {
              name: 'POSTGRES_DB'
              value: 'product_catalog'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Couchbase container app
resource couchbaseApp 'Microsoft.App/containerApps@2023-05-01' = if (deploymentMode == 'docker-only') {
  name: 'ca-couchbase-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: acaEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8091
      }
    }
    template: {
      containers: [
        {
          name: 'couchbase'
          image: 'couchbase/server:7.2.3'
          resources: {
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'COUCHBASE_ADMIN_USER'
              value: 'Administrator'
            }
            {
              name: 'COUCHBASE_ADMIN_PASSWORD'
              value: 'password'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// Kafka container app
resource kafkaApp 'Microsoft.App/containerApps@2023-05-01' = if (deploymentMode == 'docker-only') {
  name: 'ca-kafka-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: acaEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 9092
      }
    }
    template: {
      containers: [
        {
          name: 'kafka'
          image: 'apache/kafka:latest'
          resources: {
            cpu: json('1')
            memory: '2Gi'
          }
          env: [
            {
              name: 'KAFKA_NODE_ID'
              value: '1'
            }
            {
              name: 'KAFKA_PROCESS_ROLES'
              value: 'broker,controller'
            }
            {
              name: 'KAFKA_LISTENERS'
              value: 'PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093'
            }
            {
              name: 'KAFKA_ADVERTISED_LISTENERS'
              value: 'PLAINTEXT://ca-kafka-${suffix}:9092,CONTROLLER://ca-kafka-${suffix}:9093'
            }
            {
              name: 'KAFKA_LISTENER_SECURITY_PROTOCOL_MAP'
              value: 'PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT'
            }
            {
              name: 'KAFKA_CONTROLLER_LISTENER_NAMES'
              value: 'CONTROLLER'
            }
            {
              name: 'KAFKA_CONTROLLER_QUORUM_VOTERS'
              value: '1@ca-kafka-${suffix}:9093'
            }
            {
              name: 'KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR'
              value: '1'
            }
            {
              name: 'KAFKA_OFFSETS_TOPIC_MIN_ISR'
              value: '1'
            }
            {
              name: 'KAFKA_LOG_DIRS'
              value: '/tmp/kraft-combined-logs'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

// ── MANAGED SERVICES mode resources ──────────────────────────────────────────

// Azure PostgreSQL Flexible Server
module postgres 'modules/postgres.bicep' = if (deploymentMode == 'managed-services') {
  name: 'deploy-postgres'
  params: {
    suffix: suffix
    location: location
    adminLogin: postgresAdminLogin
    adminPassword: postgresAdminPassword
  }
}

// Azure Event Hubs namespace (Kafka-compatible)
module eventHub 'modules/eventhub.bicep' = if (deploymentMode == 'managed-services') {
  name: 'deploy-eventhub'
  params: {
    suffix: suffix
    location: location
  }
}

// Couchbase Capella (placeholder for manual setup)
module couchbase 'modules/cosmosdb.bicep' = if (deploymentMode == 'managed-services') {
  name: 'deploy-couchbase'
  params: {
    couchbaseConnectionString: couchbaseConnectionString
    couchbaseUsername: couchbaseUsername
    couchbasePassword: couchbasePassword
  }
}

// Azure Key Vault
module keyVault 'modules/keyvault.bicep' = if (deploymentMode == 'managed-services') {
  name: 'deploy-keyvault'
  params: {
    kvName: kvName
    location: location
    jwtSecret: jwtSecret
    postgresPassword: postgresAdminPassword
    couchbasePassword: couchbasePassword
    couchbaseConnectionString: couchbaseConnectionString
    couchbaseUsername: couchbaseUsername
  }
}

// ── Variables ────────────────────────────────────────────────────────────────

var acrLoginServer = empty(existingAcrName)
  ? newAcr!.properties.loginServer
  : existingAcr!.properties.loginServer

// ── Outputs ───────────────────────────────────────────────────────────────────
// Container App is created in GitHub Actions deploy-app job after image is pushed to ACR

output acrLoginServer string = acrLoginServer
output acrName string = resolvedAcrName
output acaEnvId string = acaEnv.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output resourceGroupName string = resourceGroup().name
output deploymentMode string = deploymentMode
output suffix string = suffix
output postgresHost string = deploymentMode == 'docker-only' ? 'ca-postgres-${suffix}' : 'postgres.postgres.svc.cluster.local'
output couchbaseHost string = deploymentMode == 'docker-only' ? 'ca-couchbase-${suffix}' : 'couchbase.couchbase.svc.cluster.local'
output kafkaHost string = deploymentMode == 'docker-only' ? 'ca-kafka-${suffix}' : 'kafka.kafka.svc.cluster.local'
