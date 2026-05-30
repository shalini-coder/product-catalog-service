targetScope = 'resourceGroup'

param environment string = 'dev'
param location string = resourceGroup().location
param appName string = 'product-catalog'

var suffix = '${appName}-${environment}'
var containerAppEnvName = 'cae-${suffix}'
var acrName = 'acrproductcatalogdev'
var acrLoginServer = '${acrName}.azurecr.io'

// Container Apps Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: listKeys(logAnalyticsWorkspace.id, '2021-06-01').primarySharedKey
      }
    }
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'law-${suffix}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 7
  }
}

// PostgreSQL
resource postgresContainerApp 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'ca-postgres-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 5432
        transport: 'tcp'
      }
      registries: []
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
              value: 'productcatalog'
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

// Kafka with KRaft (no Zookeeper)
resource kafkaContainerApp 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'ca-kafka-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 9092
        transport: 'tcp'
      }
      registries: []
    }
    template: {
      containers: [
        {
          name: 'kafka'
          image: 'confluentinc/cp-kafka:7.5.1'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          ports: [
            {
              containerPort: 9092
              protocol: 'tcp'
            }
            {
              containerPort: 29093
              protocol: 'tcp'
            }
          ]
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
              name: 'KAFKA_LISTENER_SECURITY_PROTOCOL_MAP'
              value: 'PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT,CONTROLLER:PLAINTEXT'
            }
            {
              name: 'KAFKA_LISTENERS'
              value: 'PLAINTEXT://0.0.0.0:9092,PLAINTEXT_HOST://0.0.0.0:29092,CONTROLLER://0.0.0.0:29093'
            }
            {
              name: 'KAFKA_ADVERTISED_LISTENERS'
              value: 'PLAINTEXT://ca-kafka-${suffix}:9092,PLAINTEXT_HOST://localhost:29092'
            }
            {
              name: 'KAFKA_INTER_BROKER_LISTENER_NAME'
              value: 'PLAINTEXT'
            }
            {
              name: 'KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR'
              value: '1'
            }
            {
              name: 'KAFKA_OFFSETS_TOPIC_NUM_PARTITIONS'
              value: '1'
            }
            {
              name: 'KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR'
              value: '1'
            }
            {
              name: 'KAFKA_TRANSACTION_STATE_LOG_MIN_ISR'
              value: '1'
            }
            {
              name: 'KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS'
              value: '0'
            }
            {
              name: 'KAFKA_AUTO_CREATE_TOPICS_ENABLE'
              value: 'true'
            }
            {
              name: 'KAFKA_CONTROLLER_QUORUM_VOTERS'
              value: '1@ca-kafka-${suffix}:29093'
            }
            {
              name: 'KAFKA_CONTROLLER_LISTENER_NAMES'
              value: 'CONTROLLER'
            }
            {
              name: 'KAFKA_LOG_DIRS'
              value: '/var/lib/kafka/data'
            }
            {
              name: 'CLUSTER_ID'
              value: 'MkQkRDllNTcwNTJENDM2Qg'
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

// Couchbase
resource couchbaseContainerApp 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'ca-couchbase-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 8091
        transport: 'tcp'
      }
      registries: []
    }
    template: {
      containers: [
        {
          name: 'couchbase'
          image: 'couchbase:community-7.2.0'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          ports: [
            {
              containerPort: 8091
              protocol: 'tcp'
            }
            {
              containerPort: 11210
              protocol: 'tcp'
            }
          ]
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

// Kafka UI
resource kafkaUiContainerApp 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'ca-kafka-ui-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'tcp'
      }
      registries: []
    }
    template: {
      containers: [
        {
          name: 'kafka-ui'
          image: 'provectuslabs/kafka-ui:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'KAFKA_CLUSTERS_0_NAME'
              value: 'kraft-cluster'
            }
            {
              name: 'KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS'
              value: 'ca-kafka-${suffix}:9092'
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

// Spring Boot Application
resource appContainerApp 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: 'ca-app-${suffix}'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        transport: 'tcp'
      }
      registries: [
        {
          server: acrLoginServer
          username: 'acrproductcatalogdev'
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: 'G4GrbmOskt18QaiHJcZbDGDc7kHnRWJrMacFN732mU95mcjWBWkjJQQJ99CEACYeBjFEqg7NAAACAZCRKWzE'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'app'
          image: '${acrLoginServer}/product-catalog-service:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'SPRING_PROFILES_ACTIVE'
              value: 'local'
            }
            {
              name: 'SPRING_DATASOURCE_URL'
              value: 'jdbc:postgresql://ca-postgres-${suffix}:5432/productcatalog'
            }
            {
              name: 'SPRING_DATASOURCE_USERNAME'
              value: 'postgres'
            }
            {
              name: 'SPRING_DATASOURCE_PASSWORD'
              value: 'postgres'
            }
            {
              name: 'SPRING_COUCHBASE_CONNECTION_STRING'
              value: 'couchbase://ca-couchbase-${suffix}'
            }
            {
              name: 'SPRING_COUCHBASE_USERNAME'
              value: 'Administrator'
            }
            {
              name: 'SPRING_COUCHBASE_PASSWORD'
              value: 'password'
            }
            {
              name: 'SPRING_KAFKA_BOOTSTRAP_SERVERS'
              value: 'ca-kafka-${suffix}:9092'
            }
            {
              name: 'APP_SECURITY_JWT_SECRET'
              value: 'local-dev-secret-key-minimum-32-chars-long'
            }
            {
              name: 'APP_SECURITY_JWT_EXPIRATION_MS'
              value: '86400000'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 2
      }
    }
  }
  dependsOn: [
    postgresContainerApp
    kafkaContainerApp
    couchbaseContainerApp
  ]
}

// Outputs
output containerAppEnvId string = containerAppEnv.id
output appFqdn string = appContainerApp.properties.configuration.ingress.fqdn
output kafkaUiFqdn string = kafkaUiContainerApp.properties.configuration.ingress.fqdn
output appUrl string = 'https://${appContainerApp.properties.configuration.ingress.fqdn}'
