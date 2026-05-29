// Couchbase Capella — Managed Couchbase Cloud Service
// This module is a placeholder since Couchbase Capella must be created manually.
//
// To set up Couchbase Capella:
// 1. Sign up at https://cloud.couchbase.com/
// 2. Create a project and cluster
// 3. Create a bucket named "product-catalog"
// 4. Create a user with credentials
// 5. Get the connection string (couchbases://cluster-id.cloud.couchbase.com)
//
// Then set these environment variables in Key Vault or Container Apps:
//   SPRING_COUCHBASE_CONNECTION_STRING = couchbases://<cluster-id>.cloud.couchbase.com
//   SPRING_COUCHBASE_USERNAME = <user>
//   SPRING_COUCHBASE_PASSWORD = <password>
//   SPRING_COUCHBASE_BUCKET_NAME = product-catalog

param couchbaseConnectionString string = ''
param couchbaseUsername string = ''
@secure()
param couchbasePassword string = ''

output connectionString string = couchbaseConnectionString
output username string = couchbaseUsername
output password string = couchbasePassword
