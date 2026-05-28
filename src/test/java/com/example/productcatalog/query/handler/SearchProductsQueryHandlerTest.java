package com.example.productcatalog.query.handler;

import com.example.productcatalog.query.dto.ProductDto;
import com.example.productcatalog.query.model.SearchProductsByNameQuery;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ProductQueryHandler — SearchByName")
class SearchProductsQueryHandlerTest {

    @Mock
    private ProductProjectionRepository projectionRepository;

    @InjectMocks
    private ProductQueryHandler handler;

    @Test
    @DisplayName("should return matching products as DTOs")
    void shouldReturnMatchingProducts() {
        ProductProjection p1 = new ProductProjection();
        p1.setId("1");
        p1.setName("Gaming Laptop");
        p1.setPrice(new BigDecimal("1299.99"));
        p1.setStockQuantity(10);

        ProductProjection p2 = new ProductProjection();
        p2.setId("2");
        p2.setName("Office Laptop");
        p2.setPrice(new BigDecimal("799.99"));
        p2.setStockQuantity(0);

        when(projectionRepository.findByNameContainingIgnoreCase("Laptop"))
                .thenReturn(List.of(p1, p2));

        List<ProductDto> results = handler.handle(new SearchProductsByNameQuery("Laptop"));

        assertThat(results).hasSize(2);
        assertThat(results).extracting(ProductDto::getName)
                .containsExactly("Gaming Laptop", "Office Laptop");
    }

    @Test
    @DisplayName("should return empty list when no match found")
    void shouldReturnEmptyListWhenNoMatch() {
        when(projectionRepository.findByNameContainingIgnoreCase("xyz"))
                .thenReturn(List.of());

        List<ProductDto> results = handler.handle(new SearchProductsByNameQuery("xyz"));

        assertThat(results).isEmpty();
    }
}
