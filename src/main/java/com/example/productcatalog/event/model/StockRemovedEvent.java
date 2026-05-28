package com.example.productcatalog.event.model;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.LocalDateTime;
import java.util.UUID;

public class StockRemovedEvent extends DomainEvent {

    private final UUID productId;
    private final int quantityRemoved;
    private final int newStockTotal;

    public StockRemovedEvent(UUID productId, int quantityRemoved,
                             int newStockTotal, LocalDateTime occurredAt) {
        super("StockRemoved", occurredAt);
        this.productId       = productId;
        this.quantityRemoved = quantityRemoved;
        this.newStockTotal   = newStockTotal;
    }

    @JsonCreator
    public StockRemovedEvent(
            @JsonProperty("eventId")         UUID eventId,
            @JsonProperty("eventType")       String eventType,
            @JsonProperty("occurredAt")      LocalDateTime occurredAt,
            @JsonProperty("productId")       UUID productId,
            @JsonProperty("quantityRemoved") int quantityRemoved,
            @JsonProperty("newStockTotal")   int newStockTotal) {
        super(eventId, eventType, occurredAt);
        this.productId       = productId;
        this.quantityRemoved = quantityRemoved;
        this.newStockTotal   = newStockTotal;
    }

    public UUID getProductId()      { return productId; }
    public int getQuantityRemoved() { return quantityRemoved; }
    public int getNewStockTotal()   { return newStockTotal; }
}
