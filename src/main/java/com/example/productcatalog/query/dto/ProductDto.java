package com.example.productcatalog.query.dto;

import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Read-side DTO returned by query handlers to the API layer.
 *
 * <p>Immutable and built with the Lombok builder.
 */
@Value
@Builder
public class ProductDto {
    String id;
    String name;
    String description;
    BigDecimal price;
    int stockQuantity;
    boolean inStock;
    List<String> tags;
    LocalDateTime lastUpdated;
}
