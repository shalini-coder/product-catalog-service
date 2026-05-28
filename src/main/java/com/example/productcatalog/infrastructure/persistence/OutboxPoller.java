package com.example.productcatalog.infrastructure.persistence;

import com.example.productcatalog.command.repository.OutboxRepository;
import com.example.productcatalog.common.constants.KafkaTopics;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Scheduled background job that polls the outbox table and publishes
 * any unpublished events to Kafka.
 *
 * <p>Runs every 5 seconds. Uses a separate transaction so that a publish
 * failure does not roll back the business transaction that wrote the event.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OutboxPoller {

    private final OutboxRepository             outboxRepository;
    private final KafkaTemplate<String, String> kafkaTemplate;

    @Scheduled(fixedDelayString = "${app.outbox.poll-interval-ms:5000}")
    @Transactional
    public void pollAndPublish() {
        List<OutboxEvent> pending =
                outboxRepository.findByPublishedFalseOrderByCreatedAtAsc();

        if (pending.isEmpty()) return;

        log.debug("Outbox poller found {} unpublished event(s)", pending.size());

        for (OutboxEvent event : pending) {
            try {
                String topic = KafkaTopics.fromEventType(event.getEventType());
                kafkaTemplate.send(topic, event.getAggregateId().toString(), event.getPayload());

                event.setPublished(true);
                event.setPublishedAt(LocalDateTime.now());
                outboxRepository.save(event);

                log.info("Outbox event published: id={}, type={}", event.getId(), event.getEventType());
            } catch (Exception ex) {
                log.error("Failed to publish outbox event: id={}", event.getId(), ex);
            }
        }
    }
}
