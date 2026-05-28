using '../main.bicep'

// ── Production environment parameters ─────────────────────────────────────────
// Uses managed Azure services for high availability and automated backups.
// Couchbase Capella must be provisioned separately (see AZURE_SETUP.md).

param deploymentMode       = 'managed-services'
param environment          = 'prod'
param location             = 'eastus'
param appName              = 'product-catalog'
param postgresAdminLogin   = 'catalogadmin'

// All secrets supplied at deploy time via GitHub Actions secrets / Key Vault
param jwtSecret            = ''
param postgresAdminPassword = ''
param couchbasePassword    = ''
