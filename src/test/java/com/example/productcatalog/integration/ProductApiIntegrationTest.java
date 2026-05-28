package com.example.productcatalog.integration;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.command.repository.ProductRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.*;

/**
 * Full-stack integration tests against a real embedded Spring Boot context.
 *
 * <p>Uses Testcontainers (configured in {@code application-test.yml}) for PostgreSQL.
 * Couchbase and Kafka interactions are stubbed.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@DisplayName("Product API — Integration Tests")
class ProductApiIntegrationTest {

    @Autowired TestRestTemplate restTemplate;
    @Autowired ProductRepository productRepository;

    @BeforeEach
    void setUp() {
        productRepository.deleteAll();
    }

    @Test
    @DisplayName("POST /products → 201 and Location header")
    void createProduct_returnsCreatedWithLocation() {
        ProductRequest request = ProductRequest.builder()
                .name("Integration Test Laptop")
                .description("Created in integration test")
                .price(new BigDecimal("999.99"))
                .build();

        ResponseEntity<Void> response = restTemplate
                .withBasicAuth("admin", "changeme")
                .postForEntity("/api/v1/products", request, Void.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getHeaders().getLocation()).isNotNull();
    }

    @Test
    @DisplayName("GET /products/{unknownId} → 404")
    void getProduct_returnsNotFound() {
        ResponseEntity<String> response = restTemplate
                .getForEntity("/api/v1/products/00000000-0000-0000-0000-000000000000", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
