package com.example.productcatalog.command.handler;

import com.example.productcatalog.command.model.UpdateProductCommand;
import com.example.productcatalog.command.repository.OutboxRepository;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.domain.exception.ProductNotFoundException;
import com.example.productcatalog.domain.model.ProductAggregate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ProductCommandHandler — UpdateProduct")
class UpdateProductCommandHandlerTest {

    @Mock private ProductRepository productRepository;
    @Mock private OutboxRepository  outboxRepository;
    @Mock private JsonUtil          jsonUtil;

    @InjectMocks
    private ProductCommandHandler handler;

    @Test
    @DisplayName("should update aggregate when product exists")
    void shouldUpdateAggregateWhenProductExists() {
        UUID id = UUID.randomUUID();
        ProductAggregate existing =
                ProductAggregate.create("Old Name", "old desc", new BigDecimal("10.00"));
        existing.clearEvents();

        when(productRepository.findById(id)).thenReturn(Optional.of(existing));
        when(jsonUtil.toJson(any())).thenReturn("{}");
        when(productRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        var command = UpdateProductCommand.builder()
                .productId(id)
                .name("New Name")
                .description("new desc")
                .price(new BigDecimal("20.00"))
                .build();

        assertThatCode(() -> handler.handle(command)).doesNotThrowAnyException();

        verify(productRepository).save(any());
        verify(outboxRepository, atLeastOnce()).save(any());
    }

    @Test
    @DisplayName("should throw ProductNotFoundException when product does not exist")
    void shouldThrowWhenProductNotFound() {
        UUID id = UUID.randomUUID();
        when(productRepository.findById(id)).thenReturn(Optional.empty());

        var command = UpdateProductCommand.builder()
                .productId(id)
                .name("Name")
                .price(new BigDecimal("10.00"))
                .build();

        assertThatThrownBy(() -> handler.handle(command))
                .isInstanceOf(ProductNotFoundException.class);
    }
}
