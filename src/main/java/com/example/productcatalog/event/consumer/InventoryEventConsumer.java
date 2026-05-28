package com.example.productcatalog.event.consumer;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.stereotype.Component;

/**
 * Consumes external inventory events (e.g. from a warehouse system)
 * and reconciles them with the product catalog.
 *
 * <p>Extend with actual integration logic as requirements evolve.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class InventoryEventConsumer {

    @KafkaListener(topics = "${app.kafka.topics.inventory-sync}",
                   groupId = "${spring.kafka.consumer.group-id}",
                   containerFactory = "kafkaListenerContainerFactory")
    public void onInventorySync(ConsumerRecord<String, String> record) {
        log.info("Received InventorySync event, key={}", record.key());
        // TODO: parse and apply warehouse stock reconciliation
    }
}
