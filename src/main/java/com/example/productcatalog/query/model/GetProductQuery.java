package com.example.productcatalog.query.model;

import lombok.Value;

import java.util.UUID;

/** Query to retrieve a single product by its identifier. */
@Value
public class GetProductQuery {
    UUID productId;
}
