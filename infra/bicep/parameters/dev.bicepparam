using '../main.bicep'

// ── Development environment parameters ────────────────────────────────────────
// NOTE: Use 'docker-only' to keep costs minimal in dev.
// Switch to 'managed-services' for staging/prod.

param deploymentMode       = 'docker-only'
param environment          = 'dev'
param location             = 'eastus'
param appName              = 'product-catalog'
param existingAcrName      = ''
param postgresAdminLogin   = 'catalogadmin'

// Secrets: supply via --parameters flag or Azure DevOps variable groups —
// never hard-code real values here.
// Example:
//   az deployment group create \
//     --template-file infra/bicep/main.bicep \
//     --parameters infra/bicep/parameters/dev.bicepparam \
//     --parameters jwtSecret=$JWT_SECRET \
//     --parameters couchbaseConnectionString=$COUCHBASE_CONNECTION_STRING
param jwtSecret            = ''    // override at deploy time
param postgresAdminPassword = ''   // override at deploy time
param couchbasePassword    = ''    // override at deploy time
param couchbaseConnectionString = ''  // Couchbase Capella connection string (managed-services only)
param couchbaseUsername = ''  // Couchbase Capella username (managed-services only)
