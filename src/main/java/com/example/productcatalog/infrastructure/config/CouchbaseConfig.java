package com.example.productcatalog.infrastructure.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.couchbase.repository.config.EnableCouchbaseRepositories;

/**
 * Couchbase read-side configuration.
 * Set spring.data.couchbase.enabled=false to disable (used in test profile).
 */
@Configuration
@ConditionalOnProperty(name = "spring.data.couchbase.enabled", havingValue = "true", matchIfMissing = true)
@EnableCouchbaseRepositories(basePackages = "com.example.productcatalog.query.repository")
public class CouchbaseConfig {
    // Connection details are auto-configured from application.yml:
    //   spring.couchbase.connection-string, .username, .password
    //   spring.data.couchbase.bucket-name
}
