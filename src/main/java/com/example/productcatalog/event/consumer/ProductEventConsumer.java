package com.example.productcatalog.event.consumer;

import com.example.productcatalog.common.constants.KafkaTopics;
import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.event.model.ProductAddedEvent;
import com.example.productcatalog.event.model.ProductUpdatedEvent;
import com.example.productcatalog.event.model.StockAddedEvent;
import com.example.productcatalog.event.model.StockRemovedEvent;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * Consumes product domain events from Kafka and keeps the Couchbase
 * read-side projection up to date.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ProductEventConsumer {

    private final ProductProjectionRepository projectionRepository;
    private final JsonUtil jsonUtil;

    @KafkaListener(topics = KafkaTopics.PRODUCT_ADDED,
                   groupId = "${spring.kafka.consumer.group-id}",
                   containerFactory = "kafkaListenerContainerFactory")
    public void onProductAdded(ConsumerRecord<String, String> record) {
        log.info("Received ProductAdded event, key={}", record.key());
        ProductAddedEvent event = jsonUtil.fromJson(record.value(), ProductAddedEvent.class);

        ProductProjection projection = new ProductProjection();
        projection.setId(event.getProductId().toString());
        projection.setName(event.getName());
        projection.setDescription(event.getDescription());
        projection.setPrice(event.getPrice());
        projection.setStockQuantity(0);
        projection.setLastUpdated(event.getOccurredAt());

        projectionRepository.save(projection);
        log.info("Projection created for product {}", event.getProductId());
    }

    @KafkaListener(topics = KafkaTopics.PRODUCT_UPDATED,
                   groupId = "${spring.kafka.consumer.group-id}",
                   containerFactory = "kafkaListenerContainerFactory")
    public void onProductUpdated(ConsumerRecord<String, String> record) {
        log.info("Received ProductUpdated event, key={}", record.key());
        ProductUpdatedEvent event = jsonUtil.fromJson(record.value(), ProductUpdatedEvent.class);

        projectionRepository.findById(event.getProductId().toString()).ifPresent(p -> {
            p.setName(event.getName());
            p.setDescription(event.getDescription());
            p.setPrice(event.getPrice());
            p.setLastUpdated(LocalDateTime.now());
            projectionRepository.save(p);
            log.info("Projection updated for product {}", event.getProductId());
        });
    }

    @KafkaListener(topics = KafkaTopics.STOCK_CHANGED,
                   groupId = "${spring.kafka.consumer.group-id}",
                   containerFactory = "kafkaListenerContainerFactory")
    public void onStockChanged(ConsumerRecord<String, String> record) {
        log.info("Received StockChanged event, key={}", record.key());
        // Determine event sub-type from header or payload type field
        String payload = record.value();

        if (payload.contains("\"eventType\":\"StockAdded\"")) {
            StockAddedEvent event = jsonUtil.fromJson(payload, StockAddedEvent.class);
            updateStockProjection(event.getProductId().toString(), event.getNewStockTotal());
        } else if (payload.contains("\"eventType\":\"StockRemoved\"")) {
            StockRemovedEvent event = jsonUtil.fromJson(payload, StockRemovedEvent.class);
            updateStockProjection(event.getProductId().toString(), event.getNewStockTotal());
        }
    }

    private void updateStockProjection(String productId, int newStock) {
        projectionRepository.findById(productId).ifPresent(p -> {
            p.setStockQuantity(newStock);
            p.setLastUpdated(LocalDateTime.now());
            projectionRepository.save(p);
            log.info("Stock projection updated for product {}: {} units", productId, newStock);
        });
    }
}
