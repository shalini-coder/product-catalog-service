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

// Azure Key Vault
module keyVault 'modules/keyvault.bicep' = if (deploymentMode == 'managed-services') {
  name: 'deploy-keyvault'
  params: {
    kvName: kvName
    location: location
    jwtSecret: jwtSecret
    postgresPassword: postgresAdminPassword
    couchbasePassword: couchbasePassword
  }
}

// ── Container App (application) ───────────────────────────────────────────────

var acrLoginServer = empty(existingAcrName)
  ? newAcr!.properties.loginServer
  : existingAcr!.properties.loginServer

module containerApp 'modules/container-app.bicep' = {
  name: 'deploy-container-app'
  params: {
    suffix: suffix
    location: location
    acaEnvId: acaEnv.id
    acrLoginServer: acrLoginServer
    acrName: resolvedAcrName
    deploymentMode: deploymentMode
    jwtSecret: jwtSecret
    appInsightsConnectionString: appInsights.properties.ConnectionString
    postgresHost: deploymentMode == 'managed-services' ? postgres!.outputs.fqdn : ''
    eventhubNamespace: deploymentMode == 'managed-services' ? eventHub!.outputs.namespaceName : ''
    eventhubConnectionString: deploymentMode == 'managed-services' ? eventHub!.outputs.primaryConnectionString : ''
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

output acrLoginServer string = acrLoginServer
output containerAppUrl string = containerApp.outputs.appUrl
output appInsightsConnectionString string = appInsights.properties.ConnectionString
