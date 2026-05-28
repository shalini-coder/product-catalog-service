package com.example.productcatalog.command.model;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Command to update an existing product's mutable attributes.
 */
@Value
@Builder
public class UpdateProductCommand {
    UUID productId;
    String name;
    String description;
    BigDecimal price;
}
