package com.example.productcatalog.event.model;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Raised when stock is removed from a product.
 */
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

    public UUID getProductId()      { return productId; }
    public int getQuantityRemoved() { return quantityRemoved; }
    public int getNewStockTotal()   { return newStockTotal; }
}
