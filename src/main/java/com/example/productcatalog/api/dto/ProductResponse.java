package com.example.productcatalog.api.dto;

import com.example.productcatalog.query.dto.ProductDto;
import lombok.Builder;
import lombok.Value;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * API response payload for product endpoints.
 */
@Value
@Builder
public class ProductResponse {

    String id;
    String name;
    String description;
    BigDecimal price;
    int stockQuantity;
    boolean inStock;
    List<String> tags;
    LocalDateTime lastUpdated;

    /** Convenience factory — maps from the internal query DTO. */
    public static ProductResponse from(ProductDto dto) {
        return ProductResponse.builder()
                .id(dto.getId())
                .name(dto.getName())
                .description(dto.getDescription())
                .price(dto.getPrice())
                .stockQuantity(dto.getStockQuantity())
                .inStock(dto.isInStock())
                .tags(dto.getTags())
                .lastUpdated(dto.getLastUpdated())
                .build();
    }
}
