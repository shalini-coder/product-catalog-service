package com.example.productcatalog.event.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Raised when an existing product's details are changed.
 */
public class ProductUpdatedEvent extends DomainEvent {

    private final UUID productId;
    private final String name;
    private final String description;
    private final BigDecimal price;

    public ProductUpdatedEvent(UUID productId, String name, String description,
                               BigDecimal price, LocalDateTime occurredAt) {
        super("ProductUpdated", occurredAt);
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
