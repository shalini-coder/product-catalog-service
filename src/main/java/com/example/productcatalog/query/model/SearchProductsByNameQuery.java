package com.example.productcatalog.query.model;

import lombok.Value;

/** Query to search products whose names contain the given substring. */
@Value
public class SearchProductsByNameQuery {
    String name;
}
