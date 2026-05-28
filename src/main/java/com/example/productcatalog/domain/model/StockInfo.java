package com.example.productcatalog.domain.model;

import com.example.productcatalog.domain.exception.InsufficientStockException;

import java.util.Objects;
import java.util.UUID;

/**
 * Value object encapsulating stock quantity and related business rules.
 * Immutable — any mutation returns a new instance.
 */
public final class StockInfo {

    private final int quantity;

    private StockInfo(int quantity) {
        if (quantity < 0) {
            throw new IllegalArgumentException("Stock quantity cannot be negative");
        }
        this.quantity = quantity;
    }

    public static StockInfo of(int quantity) {
        return new StockInfo(quantity);
    }

    public static StockInfo empty() {
        return new StockInfo(0);
    }

    public int getQuantity() {
        return quantity;
    }

    public boolean isInStock() {
        return quantity > 0;
    }

    public StockInfo add(int amount, UUID productId) {
        if (amount <= 0) {
            throw new IllegalArgumentException("Stock increment must be positive");
        }
        return new StockInfo(this.quantity + amount);
    }

    public StockInfo remove(int amount, UUID productId) {
        if (amount <= 0) {
            throw new IllegalArgumentException("Stock decrement must be positive");
        }
        if (amount > this.quantity) {
            throw new InsufficientStockException(productId, this.quantity, amount);
        }
        return new StockInfo(this.quantity - amount);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof StockInfo s)) return false;
        return quantity == s.quantity;
    }

    @Override
    public int hashCode() {
        return Objects.hash(quantity);
    }

    @Override
    public String toString() {
        return "StockInfo{quantity=" + quantity + "}";
    }
}
