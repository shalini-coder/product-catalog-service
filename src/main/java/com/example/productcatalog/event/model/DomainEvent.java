package com.example.productcatalog.event.model;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Base class for all domain events. Immutable after construction.
 */
public abstract class DomainEvent {

    private final UUID eventId;
    private final String eventType;
    private final LocalDateTime occurredAt;

    /** Used when raising a new event — generates a fresh eventId. */
    protected DomainEvent(String eventType, LocalDateTime occurredAt) {
        this.eventId    = UUID.randomUUID();
        this.eventType  = eventType;
        this.occurredAt = occurredAt;
    }

    /** Used by Jackson deserialization — preserves the original eventId from JSON. */
    protected DomainEvent(
            @JsonProperty("eventId")    UUID eventId,
            @JsonProperty("eventType")  String eventType,
            @JsonProperty("occurredAt") LocalDateTime occurredAt) {
        this.eventId    = eventId;
        this.eventType  = eventType;
        this.occurredAt = occurredAt;
    }

    public UUID getEventId()             { return eventId; }
    public String getEventType()         { return eventType; }
    public LocalDateTime getOccurredAt() { return occurredAt; }
}
