package com.example.productcatalog.integration;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Full-stack integration tests against a real embedded Spring Boot context.
 * PostgreSQL runs via Testcontainers (configured in application-test.yml).
 * Couchbase and Kafka are mocked — only the write side (JPA) is exercised here.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@DisplayName("Product API — Integration Tests")
class ProductApiIntegrationTest {

    @Autowired TestRestTemplate  restTemplate;
    @Autowired ProductRepository productRepository;

    // Couchbase disabled in test profile; provide mock so context starts cleanly
    @MockBean ProductProjectionRepository projectionRepository;
    // Prevent OutboxPoller from connecting to a real Kafka broker
    @MockBean KafkaTemplate<String, String> kafkaTemplate;

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
                .postForEntity("/api/v1/products", request, Void.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getHeaders().getLocation()).isNotNull();
    }

    @Test
    @DisplayName("POST /products → product is persisted in PostgreSQL")
    void createProduct_persistsToDatabase() {
        ProductRequest request = ProductRequest.builder()
                .name("Persisted Laptop")
                .price(new BigDecimal("499.99"))
                .build();

        restTemplate.postForEntity("/api/v1/products", request, Void.class);

        assertThat(productRepository.count()).isEqualTo(1);
    }

    @Test
    @DisplayName("GET /products/{unknownId} → 404")
    void getProduct_returnsNotFound() {
        ResponseEntity<String> response = restTemplate
                .getForEntity("/api/v1/products/00000000-0000-0000-0000-000000000000", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    @DisplayName("POST /products with blank name → 400")
    void createProduct_returnsValidationError() {
        ProductRequest request = ProductRequest.builder()
                .name("  ")
                .price(new BigDecimal("99.99"))
                .build();

        ResponseEntity<String> response = restTemplate
                .postForEntity("/api/v1/products", request, String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
