package com.example.productcatalog.query.handler;

import com.example.productcatalog.domain.exception.ProductNotFoundException;
import com.example.productcatalog.query.dto.ProductDto;
import com.example.productcatalog.query.model.GetAllProductsQuery;
import com.example.productcatalog.query.model.GetInStockProductsQuery;
import com.example.productcatalog.query.model.GetProductQuery;
import com.example.productcatalog.query.model.GetProductsByPriceRangeQuery;
import com.example.productcatalog.query.model.GetProductsByTagQuery;
import com.example.productcatalog.query.model.SearchProductsByNameQuery;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * Application-layer service handling all product read queries.
 *
 * <p>Returns only {@link ProductDto} objects — callers never see
 * the persistence model directly.  All methods are read-only transactions.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProductQueryHandler {

    private final ProductProjectionRepository projectionRepository;

    @Transactional(readOnly = true)
    public ProductDto handle(GetProductQuery query) {
        log.debug("Handling GetProductQuery: productId={}", query.getProductId());

        return projectionRepository.findById(query.getProductId().toString())
                .map(this::toDto)
                .orElseThrow(() -> new ProductNotFoundException(query.getProductId()));
    }

    @Transactional(readOnly = true)
    public Page<ProductDto> handle(GetAllProductsQuery query) {
        log.debug("Handling GetAllProductsQuery, pageable={}", query.getPageable());

        return projectionRepository.findAll(query.getPageable()).map(this::toDto);
    }

    @Transactional(readOnly = true)
    public List<ProductDto> handle(SearchProductsByNameQuery query) {
        log.debug("Handling SearchProductsByNameQuery: name={}", query.getName());

        return projectionRepository.findByNameContainingIgnoreCase(query.getName())
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ProductDto> handle(GetProductsByPriceRangeQuery query) {
        log.debug("Handling GetProductsByPriceRangeQuery: {}-{}", query.getMinPrice(), query.getMaxPrice());

        return projectionRepository.findByPriceBetween(query.getMinPrice(), query.getMaxPrice())
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ProductDto> handle(GetProductsByTagQuery query) {
        log.debug("Handling GetProductsByTagQuery: tag={}", query.getTag());

        return projectionRepository.findByTagsContaining(query.getTag())
                .stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ProductDto> handle(GetInStockProductsQuery query) {
        log.debug("Handling GetInStockProductsQuery");

        return projectionRepository.findByStockQuantityGreaterThan(0)
                .stream()
                .map(this::toDto)
                .toList();
    }

    // ── Mapping ───────────────────────────────────────────────────────────────

    private ProductDto toDto(ProductProjection p) {
        return ProductDto.builder()
                .id(p.getId())
                .name(p.getName())
                .description(p.getDescription())
                .price(p.getPrice())
                .stockQuantity(p.getStockQuantity())
                .inStock(p.isInStock())
                .tags(p.getTags())
                .lastUpdated(p.getLastUpdated())
                .build();
    }
}
