// Azure Key Vault — stores all application secrets
// Used when deploymentMode == 'managed-services'

param kvName string
param location string
@secure()
param jwtSecret string
@secure()
param postgresPassword string
@secure()
param couchbasePassword string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true   // use RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enabledForDeployment: false
    enabledForTemplateDeployment: true
  }
}

resource jwtSecretKv 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'app-jwt-secret'
  properties: { value: jwtSecret }
}

resource postgresPasswordKv 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'spring-datasource-password'
  properties: { value: postgresPassword }
}

resource couchbasePasswordKv 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'spring-couchbase-password'
  properties: { value: couchbasePassword }
}

output vaultUri string = keyVault.properties.vaultUri
output vaultName string = keyVault.name
