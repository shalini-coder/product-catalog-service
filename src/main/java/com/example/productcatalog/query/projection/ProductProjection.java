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
 * Spring Data Couchbase 5.x never writes the @Id field into the document body —
 * it is used only as the document key (META().id). To make the id visible in the
 * Couchbase UI and queryable via N1QL, we store it explicitly as a @Field as well.
 * Both fields must be set to the same value when saving.
 */
@Data
@Document
public class ProductProjection {

    /** Document key — used by findById(), not written to the body. */
    @Id
    private String key;

    /** Visible in the document body and queryable via N1QL. */
    @Field
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

    /** Convenience setter — keeps both key and id in sync. */
    public void setId(String id) {
        this.key = id;
        this.id  = id;
    }
}
