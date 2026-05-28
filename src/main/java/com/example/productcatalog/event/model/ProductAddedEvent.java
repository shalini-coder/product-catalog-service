package com.example.productcatalog.event.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

public class ProductAddedEvent extends DomainEvent {

    private final UUID productId;
    private final String name;
    private final String description;
    private final BigDecimal price;

    /** Raised by the domain — generates a new eventId. */
    public ProductAddedEvent(UUID productId, String name, String description,
                             BigDecimal price, LocalDateTime occurredAt) {
        super("ProductAdded", occurredAt);
        this.productId   = productId;
        this.name        = name;
        this.description = description;
        this.price       = price;
    }

    /** Used by Jackson to deserialize from the outbox payload. */
    @JsonCreator
    public ProductAddedEvent(
            @JsonProperty("eventId")     UUID eventId,
            @JsonProperty("eventType")   String eventType,
            @JsonProperty("occurredAt")  LocalDateTime occurredAt,
            @JsonProperty("productId")   UUID productId,
            @JsonProperty("name")        String name,
            @JsonProperty("description") String description,
            @JsonProperty("price")       BigDecimal price) {
        super(eventId, eventType, occurredAt);
        this.productId   = productId;
        this.name        = name;
        this.description = description;
        this.price       = price;
    }

    public UUID getProductId()     { return productId; }
    public String getName()        { return name; }
    public String getDescription() { return description; }
    public BigDecimal getPrice()   { return price; }
}
