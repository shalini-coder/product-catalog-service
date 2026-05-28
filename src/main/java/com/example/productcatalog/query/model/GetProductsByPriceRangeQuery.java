package com.example.productcatalog.query.model;

import lombok.Value;

import java.math.BigDecimal;

/** Query to retrieve products within an inclusive price range. */
@Value
public class GetProductsByPriceRangeQuery {
    BigDecimal minPrice;
    BigDecimal maxPrice;
}
