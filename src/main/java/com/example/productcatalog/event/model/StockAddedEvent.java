package com.example.productcatalog.event.model;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Raised when stock is added to a product.
 */
public class StockAddedEvent extends DomainEvent {

    private final UUID productId;
    private final int quantityAdded;
    private final int newStockTotal;

    public StockAddedEvent(UUID productId, int quantityAdded,
                           int newStockTotal, LocalDateTime occurredAt) {
        super("StockAdded", occurredAt);
        this.productId     = productId;
        this.quantityAdded = quantityAdded;
        this.newStockTotal = newStockTotal;
    }

    public UUID getProductId()    { return productId; }
    public int getQuantityAdded() { return quantityAdded; }
    public int getNewStockTotal() { return newStockTotal; }
}
