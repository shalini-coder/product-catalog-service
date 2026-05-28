package com.example.productcatalog.query.repository;

import com.example.productcatalog.query.projection.ProductProjection;
import org.springframework.data.couchbase.repository.CouchbaseRepository;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/**
 * Couchbase repository for the product read projection.
 *
 * <p>Only used on the query (read) side — never from command handlers.
 */
@Repository
public interface ProductProjectionRepository
        extends CouchbaseRepository<ProductProjection, String> {

    List<ProductProjection> findByNameContainingIgnoreCase(String name);

    List<ProductProjection> findByPriceBetween(BigDecimal minPrice, BigDecimal maxPrice);

    List<ProductProjection> findByTagsContaining(String tag);

    List<ProductProjection> findByStockQuantityGreaterThan(int minStock);
}
