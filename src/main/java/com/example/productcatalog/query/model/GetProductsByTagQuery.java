package com.example.productcatalog.query.model;

import lombok.Value;

/** Query to retrieve all products that carry a specific tag. */
@Value
public class GetProductsByTagQuery {
    String tag;
}
