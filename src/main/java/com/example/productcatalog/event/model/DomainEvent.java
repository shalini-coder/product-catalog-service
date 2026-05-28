package com.example.productcatalog.event.model;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Base class for all domain events.
 *
 * <p>Immutable after construction. Sub-classes add event-specific payload fields.
 */
public abstract class DomainEvent {

    private final UUID eventId;
    private final String eventType;
    private final LocalDateTime occurredAt;

    protected DomainEvent(String eventType, LocalDateTime occurredAt) {
        this.eventId    = UUID.randomUUID();
        this.eventType  = eventType;
        this.occurredAt = occurredAt;
    }

    public UUID getEventId()          { return eventId; }
    public String getEventType()      { return eventType; }
    public LocalDateTime getOccurredAt() { return occurredAt; }
}
