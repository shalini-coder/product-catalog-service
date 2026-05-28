package com.example.productcatalog.command.handler;

import com.example.productcatalog.command.model.AddProductCommand;
import com.example.productcatalog.command.repository.DomainEventRepository;
import com.example.productcatalog.command.repository.OutboxRepository;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.domain.model.ProductAggregate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ProductCommandHandler — AddProduct")
class AddProductCommandHandlerTest {

    @Mock private ProductRepository     productRepository;
    @Mock private OutboxRepository      outboxRepository;
    @Mock private DomainEventRepository domainEventRepository;
    @Mock private JsonUtil              jsonUtil;

    @InjectMocks
    private ProductCommandHandler handler;

    @Test
    @DisplayName("should save aggregate and write outbox event, returning a UUID")
    void shouldSaveAggregateAndOutboxEvent() {
        // Arrange
        var command = AddProductCommand.builder()
                .name("Gaming Laptop")
                .description("High-performance")
                .price(new BigDecimal("1299.99"))
                .build();

        when(jsonUtil.toJson(any())).thenReturn("{}");
        when(productRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        // Act
        UUID id = handler.handle(command);

        // Assert
        assertThat(id).isNotNull();

        ArgumentCaptor<ProductAggregate> captor = ArgumentCaptor.forClass(ProductAggregate.class);
        verify(productRepository).save(captor.capture());
        assertThat(captor.getValue().getName()).isEqualTo("Gaming Laptop");

        verify(outboxRepository, atLeastOnce()).save(any());
    }

    @Test
    @DisplayName("should throw when command has blank name")
    void shouldThrowOnBlankName() {
        var command = AddProductCommand.builder()
                .name("  ")
                .price(new BigDecimal("10.00"))
                .build();

        assertThatIllegalArgumentException()
                .isThrownBy(() -> handler.handle(command));

        verifyNoInteractions(productRepository, outboxRepository);
    }
}
