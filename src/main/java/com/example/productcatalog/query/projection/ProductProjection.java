package com.example.productcatalog.query.projection;

import lombok.Data;
import org.springframework.data.annotation.Id;
import org.springframework.data.couchbase.core.mapping.Document;
import org.springframework.data.couchbase.core.mapping.Field;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Denormalized Couchbase document for the product read model.
 *
 * <p>Populated and kept current by {@link com.example.productcatalog.event.consumer.ProductEventConsumer}.
 * Contains all data a query might need — no join required.
 */
@Data
@Document
public class ProductProjection {

    @Id
    private String id;

    @Field
    private String name;

    @Field
    private String description;

    @Field
    private BigDecimal price;

    @Field
    private int stockQuantity;

    @Field
    private List<String> tags;

    @Field
    private LocalDateTime lastUpdated;

    public boolean isInStock() {
        return stockQuantity > 0;
    }
}
