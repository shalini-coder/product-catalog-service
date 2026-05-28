package com.example.productcatalog.domain.exception;

import java.util.UUID;

/**
 * Thrown when an attempt is made to remove more stock than is currently available.
 */
public class InsufficientStockException extends RuntimeException {

    public InsufficientStockException(UUID productId, int available, int requested) {
        super(String.format(
            "Insufficient stock for product %s. Available: %d, Requested: %d",
            productId, available, requested
        ));
    }

    public InsufficientStockException(String message) {
        super(message);
    }
}
