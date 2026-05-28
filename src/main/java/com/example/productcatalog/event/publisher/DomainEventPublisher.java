package com.example.productcatalog.event.publisher;

import com.example.productcatalog.common.constants.KafkaTopics;
import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.event.model.DomainEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

/**
 * Publishes domain events to Kafka topics.
 *
 * <p>Uses constructor injection (no field {@code @Autowired}).
 * Failure is logged; callers should rely on the outbox pattern for guaranteed delivery.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DomainEventPublisher implements EventPublisher {

    private final KafkaTemplate<String, String> kafkaTemplate;
    private final JsonUtil jsonUtil;

    @Override
    public void publish(String topic, DomainEvent event) {
        try {
            String payload = jsonUtil.toJson(event);
            kafkaTemplate.send(topic, event.getEventId().toString(), payload);
            log.info("Published event [{}] to topic [{}]", event.getEventType(), topic);
        } catch (Exception ex) {
            log.error("Failed to publish event [{}] to topic [{}]",
                    event.getEventType(), topic, ex);
        }
    }

    /** Convenience method — resolves the topic automatically from the event type. */
    public void publishToDefaultTopic(DomainEvent event) {
        String topic = KafkaTopics.fromEventType(event.getEventType());
        publish(topic, event);
    }
}
