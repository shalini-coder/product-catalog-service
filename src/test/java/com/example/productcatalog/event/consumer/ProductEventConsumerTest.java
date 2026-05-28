package com.example.productcatalog.event.consumer;

import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.event.model.ProductAddedEvent;
import com.example.productcatalog.query.projection.ProductProjection;
import com.example.productcatalog.query.repository.ProductProjectionRepository;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("ProductEventConsumer")
class ProductEventConsumerTest {

    @Mock private ProductProjectionRepository projectionRepository;
    @Mock private JsonUtil                    jsonUtil;

    @InjectMocks
    private ProductEventConsumer consumer;

    @Test
    @DisplayName("onProductAdded should create a new projection document")
    void onProductAdded_shouldCreateProjection() {
        UUID id = UUID.randomUUID();
        ProductAddedEvent event = new ProductAddedEvent(
                id, "Gaming Laptop", "High-performance",
                new BigDecimal("1299.99"), LocalDateTime.now());

        ConsumerRecord<String, String> record = new ConsumerRecord<>("product.added", 0, 0, id.toString(), "{}");
        when(jsonUtil.fromJson("{}", ProductAddedEvent.class)).thenReturn(event);

        consumer.onProductAdded(record);

        ArgumentCaptor<ProductProjection> captor = ArgumentCaptor.forClass(ProductProjection.class);
        verify(projectionRepository).save(captor.capture());

        ProductProjection saved = captor.getValue();
        assertThat(saved.getId()).isEqualTo(id.toString());
        assertThat(saved.getName()).isEqualTo("Gaming Laptop");
        assertThat(saved.getStockQuantity()).isZero();
    }
}
