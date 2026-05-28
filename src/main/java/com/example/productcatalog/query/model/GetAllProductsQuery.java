package com.example.productcatalog.query.model;

import lombok.Value;
import org.springframework.data.domain.Pageable;

/** Query to retrieve all products with pagination. */
@Value
public class GetAllProductsQuery {
    Pageable pageable;
}
