package com.example.productcatalog.integration;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.test.context.ActiveProfiles;

import java.math.BigDecimal;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.*;
import static org.awaitility.Awaitility.await;

/**
 * Tests that verify the full event-processing pipeline:
 * API → Command Handler → Outbox → Kafka → Event Consumer → Couchbase projection.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@DisplayName("Event Processing — Integration Tests")
class EventProcessingIntegrationTest {

    @Autowired TestRestTemplate            restTemplate;
    @Autowired ProductRepository           commandRepository;
    @Autowired ProductProjectionRepository projectionRepository;

    @BeforeEach
    void setUp() {
        projectionRepository.deleteAll();
        commandRepository.deleteAll();
    }

    @Test
    @DisplayName("Creating a product via API eventually creates a Couchbase projection")
    void createProduct_eventuallyCreatesProjection() {
        ProductRequest request = ProductRequest.builder()
                .name("Event Test Laptop")
                .price(new BigDecimal("799.99"))
                .build();

        var createResp = restTemplate
                .withBasicAuth("admin", "changeme")
                .postForEntity("/api/v1/products", request, Void.class);

        assertThat(createResp.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        String location = createResp.getHeaders().getLocation().toString();
        String productId = location.substring(location.lastIndexOf("/") + 1);

        // Wait up to 10 s for the event consumer to update the projection
        await().atMost(10, TimeUnit.SECONDS)
               .pollInterval(500, TimeUnit.MILLISECONDS)
               .untilAsserted(() ->
                       assertThat(projectionRepository.findById(productId)).isPresent());
    }
}
