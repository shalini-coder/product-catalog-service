package com.example.productcatalog.infrastructure.config;

import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.transaction.annotation.EnableTransactionManagement;

/**
 * JPA / Hibernate configuration.
 *
 * <p>Scans only the packages relevant to the write side so that
 * Couchbase documents are not accidentally picked up by Hibernate.
 */
@Configuration
@EnableTransactionManagement
@EnableJpaRepositories(basePackages = {
    "com.example.productcatalog.command.repository"
})
@EntityScan(basePackages = {
    "com.example.productcatalog.domain.model",
    "com.example.productcatalog.infrastructure.persistence"
})
public class PostgresConfig {
    // DataSource is auto-configured by Spring Boot from application.yml
}
