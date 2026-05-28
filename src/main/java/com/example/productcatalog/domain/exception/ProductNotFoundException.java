package com.example.productcatalog.domain.exception;

import java.util.UUID;

/**
 * Thrown when a requested product does not exist in the catalog.
 */
public class ProductNotFoundException extends RuntimeException {

    public ProductNotFoundException(UUID productId) {
        super("Product not found: " + productId);
    }

    public ProductNotFoundException(String message) {
        super(message);
    }
}
