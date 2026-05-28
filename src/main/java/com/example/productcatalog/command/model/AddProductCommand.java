package com.example.productcatalog.command.model;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;

/**
 * Command to create a new product in the catalog.
 *
 * <p>Immutable record-style object — use {@link #builder()} for construction.
 */
@Value
@Builder
public class AddProductCommand {
    String name;
    String description;
    BigDecimal price;
}
