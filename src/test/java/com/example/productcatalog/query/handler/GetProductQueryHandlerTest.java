package com.example.productcatalog.query.handler;

import com.example.productcatalog.domain.exception.ProductNotFoundException;
import com.example.productcatalog.query.dto.ProductDto;
import com.example.productcatalog.query.model.GetProductQuery;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ProductQueryHandler — GetProduct")
class GetProductQueryHandlerTest {

    @Mock
    private ProductProjectionRepository projectionRepository;

    @InjectMocks
    private ProductQueryHandler handler;

    @Test
    @DisplayName("should return DTO when projection exists")
    void shouldReturnDtoWhenProjectionExists() {
        UUID id = UUID.randomUUID();

        ProductProjection projection = new ProductProjection();
        projection.setId(id.toString());
        projection.setName("Gaming Laptop");
        projection.setDescription("High-performance");
        projection.setPrice(new BigDecimal("1299.99"));
        projection.setStockQuantity(5);
        projection.setLastUpdated(LocalDateTime.now());

        when(projectionRepository.findById(id.toString())).thenReturn(Optional.of(projection));

        ProductDto dto = handler.handle(new GetProductQuery(id));

        assertThat(dto.getId()).isEqualTo(id.toString());
        assertThat(dto.getName()).isEqualTo("Gaming Laptop");
        assertThat(dto.isInStock()).isTrue();
    }

    @Test
    @DisplayName("should throw ProductNotFoundException when projection is absent")
    void shouldThrowWhenProjectionAbsent() {
        UUID id = UUID.randomUUID();
        when(projectionRepository.findById(id.toString())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> handler.handle(new GetProductQuery(id)))
                .isInstanceOf(ProductNotFoundException.class);
    }
}
