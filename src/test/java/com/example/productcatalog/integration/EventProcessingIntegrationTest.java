package com.example.productcatalog.integration;

import com.example.productcatalog.api.dto.ProductRequest;
import com.example.productcatalog.command.repository.OutboxRepository;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.kafka.test.context.EmbeddedKafka;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import java.math.BigDecimal;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.verify;

/**
 * Verifies the full event-processing pipeline:
 * API → Command Handler → Outbox → OutboxPoller → Kafka → EventConsumer →
 * Couchbase projection.
 *
 * Kafka runs via @EmbeddedKafka. Couchbase is mocked — we verify the consumer
 * called projectionRepository.save() with the correct data.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@EmbeddedKafka(partitions = 1, topics = { "product.added", "product.updated", "product.stock.changed",
        "inventory.sync" })
@DisplayName("Event Processing — Integration Tests")
class EventProcessingIntegrationTest {

    @Autowired
    TestRestTemplate restTemplate;
    @Autowired
    ProductRepository commandRepository;
    @Autowired
    OutboxRepository outboxRepository;

    @MockBean
    ProductProjectionRepository projectionRepository;

    @DynamicPropertySource
    static void kafkaProperties(DynamicPropertyRegistry registry) {
        // Overrides application-test.yml bootstrap-servers with the embedded broker
        // address
        registry.add("spring.kafka.bootstrap-servers",
                () -> System.getProperty("spring.embedded.kafka.brokers", "localhost:9092"));
    }

    @BeforeEach
    void setUp() {
        commandRepository.deleteAll();
        outboxRepository.deleteAll();
    }

    @Test
    @DisplayName("Creating a product via API eventually triggers a Couchbase projection save")
    void createProduct_eventuallyCreatesProjection() {
        ProductRequest request = ProductRequest.builder()
                .name("Event Test Laptop")
                .price(new BigDecimal("799.99"))
                .build();

        var createResp = restTemplate.postForEntity("/api/v1/products", request, Void.class);
        assertThat(createResp.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        // Wait for OutboxPoller → Kafka → ProductEventConsumer →
        // projectionRepository.save()
        await().atMost(Duration.ofSeconds(15))
                .pollDelay(Duration.ofMillis(100))
                .pollInterval(Duration.ofMillis(500))
                .untilAsserted(() -> {
                    ArgumentCaptor<ProductProjection> captor = ArgumentCaptor.forClass(ProductProjection.class);
                    verify(projectionRepository, atLeastOnce()).save(captor.capture());
                    assertThat(captor.getValue().getName()).isEqualTo("Event Test Laptop");
                });
    }

    @Test
    @DisplayName("Creating a product marks the outbox event as published")
    void createProduct_marksOutboxEventPublished() {
        restTemplate.postForEntity("/api/v1/products",
                ProductRequest.builder().name("Outbox Test").price(new BigDecimal("50.00")).build(),
                Void.class);

        await().atMost(Duration.ofSeconds(10))
                .pollDelay(Duration.ofMillis(100))
                .pollInterval(Duration.ofMillis(500))
                .untilAsserted(() -> assertThat(outboxRepository.findByPublishedFalseOrderByCreatedAtAsc()).isEmpty());
    }
}
