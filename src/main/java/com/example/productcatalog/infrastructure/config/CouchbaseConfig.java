package com.example.productcatalog.infrastructure.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.couchbase.repository.config.EnableCouchbaseRepositories;

/**
 * Couchbase read-side configuration.
 *
 * <p>Scans only the query repository package so that JPA repositories
 * are not picked up by the Couchbase infrastructure.
 */
@Configuration
@EnableCouchbaseRepositories(basePackages = "com.example.productcatalog.query.repository")
public class CouchbaseConfig {
    // Connection details are auto-configured from application.yml:
    //   spring.couchbase.connection-string, .username, .password
    //   spring.data.couchbase.bucket-name
}
