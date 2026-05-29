#!/bin/bash

set -e

# Configuration
RESOURCE_GROUP="rg-product-catalog-poc"
LOCATION="eastus"
ACR_NAME="acrproductcatalogdev"
ENVIRONMENT_NAME="acaenv-product-catalog-dev"
APP_NAME="product-catalog-service"

echo "=== Azure Container Apps Deployment ==="

# 1. Create ACR (if doesn't exist)
echo "Creating Azure Container Registry..."
az acr create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --sku Basic \
  2>/dev/null || echo "ACR already exists"

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --query loginServer -o tsv)

echo "ACR Login Server: $ACR_LOGIN_SERVER"

# 2. Create Container Apps Environment (if doesn't exist)
echo "Creating Container Apps Environment..."
az containerapp env create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ENVIRONMENT_NAME" \
  --location "$LOCATION" \
  2>/dev/null || echo "Environment already exists"

# Get environment ID
ENV_ID=$(az containerapp env show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ENVIRONMENT_NAME" \
  --query id -o tsv)

# 3. Build and push Docker image
echo "Building and pushing Docker image..."
az acr build \
  --registry "$ACR_NAME" \
  --image "$APP_NAME:latest" \
  .

# 4. Deploy Zookeeper
echo "Deploying Zookeeper..."
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-zookeeper-product-catalog-dev" \
  --environment "$ENVIRONMENT_NAME" \
  --image "confluentinc/cp-zookeeper:7.5.1" \
  --cpu 1 \
  --memory 2Gi \
  --target-port 2181 \
  --ingress internal \
  --env-vars \
    ZOOKEEPER_CLIENT_PORT=2181 \
    ZOOKEEPER_TICK_TIME=2000 \
  2>/dev/null || echo "Zookeeper already exists, updating..."

az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-zookeeper-product-catalog-dev" \
  --image "confluentinc/cp-zookeeper:7.5.1" \
  --set-env-vars \
    ZOOKEEPER_CLIENT_PORT=2181 \
    ZOOKEEPER_TICK_TIME=2000 \
  2>/dev/null || true

# 5. Deploy Kafka
echo "Deploying Kafka..."
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-kafka-product-catalog-dev" \
  --environment "$ENVIRONMENT_NAME" \
  --image "confluentinc/cp-kafka:7.5.1" \
  --cpu 1 \
  --memory 2Gi \
  --target-port 9092 \
  --ingress internal \
  --env-vars \
    KAFKA_BROKER_ID=1 \
    KAFKA_ZOOKEEPER_CONNECT="ca-zookeeper-product-catalog-dev:2181" \
    KAFKA_LISTENERS="PLAINTEXT://0.0.0.0:9092" \
    KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://ca-kafka-product-catalog-dev:9092" \
    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP="PLAINTEXT:PLAINTEXT" \
    KAFKA_INTER_BROKER_LISTENER_NAME="PLAINTEXT" \
    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR="1" \
    KAFKA_AUTO_CREATE_TOPICS_ENABLE="true" \
    KAFKA_ZOOKEEPER_SESSION_TIMEOUT_MS="60000" \
    KAFKA_ZOOKEEPER_CONNECTION_TIMEOUT_MS="60000" \
  2>/dev/null || echo "Kafka already exists, updating..."

az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-kafka-product-catalog-dev" \
  --image "confluentinc/cp-kafka:7.5.1" \
  --set-env-vars \
    KAFKA_BROKER_ID=1 \
    KAFKA_ZOOKEEPER_CONNECT="ca-zookeeper-product-catalog-dev:2181" \
    KAFKA_LISTENERS="PLAINTEXT://0.0.0.0:9092" \
    KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://ca-kafka-product-catalog-dev:9092" \
    KAFKA_LISTENER_SECURITY_PROTOCOL_MAP="PLAINTEXT:PLAINTEXT" \
    KAFKA_INTER_BROKER_LISTENER_NAME="PLAINTEXT" \
    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR="1" \
    KAFKA_AUTO_CREATE_TOPICS_ENABLE="true" \
    KAFKA_ZOOKEEPER_SESSION_TIMEOUT_MS="60000" \
    KAFKA_ZOOKEEPER_CONNECTION_TIMEOUT_MS="60000" \
  2>/dev/null || true

# 6. Deploy PostgreSQL
echo "Deploying PostgreSQL..."
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-postgres-product-catalog-dev" \
  --environment "$ENVIRONMENT_NAME" \
  --image "postgres:16-alpine" \
  --cpu 0.5 \
  --memory 1Gi \
  --target-port 5432 \
  --ingress internal \
  --env-vars \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=product_catalog \
  2>/dev/null || echo "PostgreSQL already exists, updating..."

az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-postgres-product-catalog-dev" \
  --image "postgres:16-alpine" \
  --set-env-vars \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    POSTGRES_DB=product_catalog \
  2>/dev/null || true

# 7. Deploy Couchbase
echo "Deploying Couchbase..."
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-couchbase-product-catalog-dev" \
  --environment "$ENVIRONMENT_NAME" \
  --image "couchbase/server:7.2.3" \
  --cpu 1 \
  --memory 2Gi \
  --target-port 8091 \
  --ingress internal \
  --env-vars \
    COUCHBASE_ADMIN_USER=Administrator \
    COUCHBASE_ADMIN_PASSWORD=password \
  2>/dev/null || echo "Couchbase already exists, updating..."

az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-couchbase-product-catalog-dev" \
  --image "couchbase/server:7.2.3" \
  --set-env-vars \
    COUCHBASE_ADMIN_USER=Administrator \
    COUCHBASE_ADMIN_PASSWORD=password \
  2>/dev/null || true

# 8. Deploy Application
echo "Deploying Application..."
az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-product-catalog-dev" \
  --environment "$ENVIRONMENT_NAME" \
  --image "$ACR_LOGIN_SERVER/$APP_NAME:latest" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-username $(az acr credential show --name "$ACR_NAME" --query "username" -o tsv) \
  --registry-password $(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" -o tsv) \
  --cpu 0.5 \
  --memory 1Gi \
  --target-port 8080 \
  --ingress external \
  --env-vars \
    SPRING_PROFILES_ACTIVE=prod \
    SPRING_DATASOURCE_URL="jdbc:postgresql://ca-postgres-product-catalog-dev:5432/product_catalog" \
    SPRING_DATASOURCE_USERNAME=postgres \
    SPRING_DATASOURCE_PASSWORD=postgres \
    SPRING_COUCHBASE_CONNECTION_STRING="couchbase://ca-couchbase-product-catalog-dev" \
    SPRING_COUCHBASE_USERNAME=Administrator \
    SPRING_COUCHBASE_PASSWORD=password \
    SPRING_KAFKA_BOOTSTRAP_SERVERS="ca-kafka-product-catalog-dev:9092" \
  2>/dev/null || echo "Application already exists, updating..."

az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "ca-product-catalog-dev" \
  --image "$ACR_LOGIN_SERVER/$APP_NAME:latest" \
  --set-env-vars \
    SPRING_PROFILES_ACTIVE=prod \
    SPRING_DATASOURCE_URL="jdbc:postgresql://ca-postgres-product-catalog-dev:5432/product_catalog" \
    SPRING_DATASOURCE_USERNAME=postgres \
    SPRING_DATASOURCE_PASSWORD=postgres \
    SPRING_COUCHBASE_CONNECTION_STRING="couchbase://ca-couchbase-product-catalog-dev" \
    SPRING_COUCHBASE_USERNAME=Administrator \
    SPRING_COUCHBASE_PASSWORD=password \
    SPRING_KAFKA_BOOTSTRAP_SERVERS="ca-kafka-product-catalog-dev:9092" \
  2>/dev/null || true

echo ""
echo "=== Deployment Complete ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "ACR: $ACR_LOGIN_SERVER"
echo "Environment: $ENVIRONMENT_NAME"
echo ""
echo "Wait 2-3 minutes for all containers to be healthy, then check:"
echo "az containerapp show -g $RESOURCE_GROUP -n ca-product-catalog-dev --query properties.latestRevisionFqdn"
