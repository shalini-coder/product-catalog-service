package com.example.productcatalog.domain.service;

import com.example.productcatalog.domain.model.ProductAggregate;

import java.math.BigDecimal;

/**
 * Domain service for cross-aggregate or cross-entity business logic
 * that does not naturally belong to a single aggregate.
 *
 * <p>No Spring annotations — pure domain logic.
 */
public class ProductDomainService {

    /**
     * Applies a percentage discount to a product's price.
     *
     * @param product          the target aggregate
     * @param discountPercent  discount in percent (0–100)
     */
    public void applyDiscount(ProductAggregate product, BigDecimal discountPercent) {
        if (discountPercent == null
                || discountPercent.compareTo(BigDecimal.ZERO) < 0
                || discountPercent.compareTo(BigDecimal.valueOf(100)) > 0) {
            throw new IllegalArgumentException("Discount must be between 0 and 100");
        }

        BigDecimal factor   = BigDecimal.ONE.subtract(discountPercent.divide(BigDecimal.valueOf(100)));
        BigDecimal newPrice = product.getPrice().multiply(factor);

        product.update(product.getName(), product.getDescription(), newPrice);
    }
}
