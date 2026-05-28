// Azure Container App — the application itself
// Works for both deployment modes

param suffix string
param location string
param acaEnvId string
param acrLoginServer string
param acrName string
param deploymentMode string
param appInsightsConnectionString string
@secure()
param jwtSecret string

// managed-services mode only (empty string in docker-only mode)
param postgresHost string = ''
param eventhubNamespace string = ''
@secure()
param eventhubConnectionString string = ''

// The image tag is overridden at deploy time by CI/CD
var imageTag = 'latest'

// ── ACR pull credentials ───────────────────────────────────────────────────

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// ── Environment variables for docker-only mode ─────────────────────────────

var dockerOnlyEnv = [
  { name: 'SPRING_PROFILES_ACTIVE', value: 'prod' }
  { name: 'SPRING_DATASOURCE_URL',  value: 'jdbc:postgresql://postgres:5432/productcatalog' }
  { name: 'SPRING_DATASOURCE_USERNAME', value: 'catalog_user' }
  { name: 'SPRING_KAFKA_BOOTSTRAP_SERVERS', value: 'kafka:9092' }
  { name: 'SPRING_COUCHBASE_CONNECTION_STRING', value: 'couchbase://couchbase' }
]

// ── Environment variables for managed-services mode ───────────────────────

var managedServicesEnv = [
  { name: 'SPRING_PROFILES_ACTIVE', value: 'azure' }
  { name: 'SPRING_DATASOURCE_URL', value: 'jdbc:postgresql://${postgresHost}:5432/productcatalog?sslmode=require' }
  { name: 'AZURE_EVENTHUB_NAMESPACE', value: eventhubNamespace }
  { name: 'AZURE_APPINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
]

var envVars = deploymentMode == 'managed-services' ? managedServicesEnv : dockerOnlyEnv

// ── Secrets ────────────────────────────────────────────────────────────────

var secrets = deploymentMode == 'managed-services' ? [
  { name: 'app-jwt-secret',           value: jwtSecret }
  { name: 'eventhub-connection-string', value: eventhubConnectionString }
  { name: 'acr-password',             value: acr.listCredentials().passwords[0].value }
] : [
  { name: 'app-jwt-secret', value: jwtSecret }
  { name: 'acr-password',   value: acr.listCredentials().passwords[0].value }
]

// ── Container App ──────────────────────────────────────────────────────────

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'ca-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: acaEnvId
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
      }
      registries: [
        {
          server: acrLoginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: 'product-catalog-service'
          image: '${acrLoginServer}/product-catalog-service:${imageTag}'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: union(envVars, [
            { name: 'APP_JWT_SECRET', secretRef: 'app-jwt-secret' }
          ])
          probes: [
            {
              type: 'Liveness'
              httpGet: { path: '/actuator/health/liveness', port: 8080 }
              initialDelaySeconds: 40
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: { path: '/actuator/health/readiness', port: 8080 }
              initialDelaySeconds: 20
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 5
        rules: [
          {
            name: 'http-scale'
            http: { metadata: { concurrentRequests: '20' } }
          }
        ]
      }
    }
  }
}

output appUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output appName string = containerApp.name
