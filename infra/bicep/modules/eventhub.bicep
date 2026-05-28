// Azure Event Hubs namespace — Kafka-compatible
// Used when deploymentMode == 'managed-services'

param suffix string
param location string

var topicNames = [
  'product.added'
  'product.updated'
  'product.stock.changed'
  'inventory.sync'
]

resource namespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: 'evhns-${suffix}'
  location: location
  sku: {
    name: 'Standard'      // Standard tier required for Kafka protocol
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    kafkaEnabled: true    // ← enables the Kafka-compatible endpoint
    minimumTlsVersion: '1.2'
  }
}

// Create one Event Hub per topic name
resource eventHubs 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = [
  for topic in topicNames: {
    parent: namespace
    name: replace(topic, '.', '-')   // AZ resource names can't contain dots
    properties: {
      messageRetentionInDays: 1
      partitionCount: 3
    }
  }
]

// Consumer group for product-catalog-service
resource consumerGroups 'Microsoft.EventHub/namespaces/eventhubs/consumergroups@2023-01-01-preview' = [
  for (topic, i) in topicNames: {
    parent: eventHubs[i]
    name: 'product-catalog-cg'
  }
]

// Shared access policy with Send + Listen permissions
resource sendListenPolicy 'Microsoft.EventHub/namespaces/authorizationRules@2023-01-01-preview' = {
  parent: namespace
  name: 'ProductCatalogPolicy'
  properties: {
    rights: ['Send', 'Listen']
  }
}

output namespaceName string = namespace.name
output primaryConnectionString string = sendListenPolicy.listKeys().primaryConnectionString
output bootstrapServers string = '${namespace.name}.servicebus.windows.net:9093'
