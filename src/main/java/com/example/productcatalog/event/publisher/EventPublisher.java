package com.example.productcatalog.event.publisher;

import com.example.productcatalog.event.model.DomainEvent;

/**
 * Contract for publishing domain events to an external broker.
 */
public interface EventPublisher {

    /**
     * Publishes a single domain event.
     *
     * @param topic the target topic/channel
     * @param event the event to publish
     */
    void publish(String topic, DomainEvent event);
}
