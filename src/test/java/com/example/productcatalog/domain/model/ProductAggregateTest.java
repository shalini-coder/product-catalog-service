package com.example.productcatalog.domain.model;

import com.example.productcatalog.domain.exception.InsufficientStockException;
import com.example.productcatalog.event.model.ProductAddedEvent;
import com.example.productcatalog.event.model.StockAddedEvent;
import com.example.productcatalog.event.model.StockRemovedEvent;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.*;

@DisplayName("ProductAggregate")
class ProductAggregateTest {

    // ── Factory ───────────────────────────────────────────────────────────────

    @Nested
    @DisplayName("create()")
    class Create {

        @Test
        @DisplayName("should create product and raise ProductAddedEvent")
        void shouldCreateProductAndRaiseEvent() {
            var product = ProductAggregate.create("Laptop", "Gaming laptop", new BigDecimal("1299.99"));

            assertThat(product.getId()).isNotNull();
            assertThat(product.getName()).isEqualTo("Laptop");
            assertThat(product.getPrice()).isEqualByComparingTo("1299.99");
            assertThat(product.getStockQuantity()).isZero();
            assertThat(product.getDomainEvents())
                    .hasSize(1)
                    .first()
                    .isInstanceOf(ProductAddedEvent.class);
        }

        @Test
        @DisplayName("should throw when name is blank")
        void shouldThrowWhenNameIsBlank() {
            assertThatIllegalArgumentException()
                    .isThrownBy(() -> ProductAggregate.create("  ", "desc", new BigDecimal("10")))
                    .withMessageContaining("name cannot be blank");
        }

        @Test
        @DisplayName("should throw when price is zero")
        void shouldThrowWhenPriceIsZero() {
            assertThatIllegalArgumentException()
                    .isThrownBy(() -> ProductAggregate.create("Laptop", "desc", BigDecimal.ZERO))
                    .withMessageContaining("greater than zero");
        }
    }

    // ── Stock ─────────────────────────────────────────────────────────────────

    @Nested
    @DisplayName("addStock()")
    class AddStock {

        @Test
        @DisplayName("should increase stock and raise StockAddedEvent")
        void shouldIncreaseStockAndRaiseEvent() {
            var product = ProductAggregate.create("Laptop", "desc", new BigDecimal("999.00"));
            product.clearEvents();

            product.addStock(10);

            assertThat(product.getStockQuantity()).isEqualTo(10);
            assertThat(product.isInStock()).isTrue();
            assertThat(product.getDomainEvents())
                    .hasSize(1)
                    .first()
                    .isInstanceOf(StockAddedEvent.class);
        }
    }

    @Nested
    @DisplayName("removeStock()")
    class RemoveStock {

        @Test
        @DisplayName("should decrease stock and raise StockRemovedEvent")
        void shouldDecreaseStockAndRaiseEvent() {
            var product = ProductAggregate.create("Laptop", "desc", new BigDecimal("999.00"));
            product.addStock(20);
            product.clearEvents();

            product.removeStock(5);

            assertThat(product.getStockQuantity()).isEqualTo(15);
            assertThat(product.getDomainEvents())
                    .hasSize(1)
                    .first()
                    .isInstanceOf(StockRemovedEvent.class);
        }

        @Test
        @DisplayName("should throw InsufficientStockException when removing more than available")
        void shouldThrowWhenInsufficientStock() {
            var product = ProductAggregate.create("Laptop", "desc", new BigDecimal("999.00"));
            product.addStock(5);
            product.clearEvents();

            assertThatThrownBy(() -> product.removeStock(10))
                    .isInstanceOf(InsufficientStockException.class)
                    .hasMessageContaining("Insufficient stock");
        }
    }

    // ── Update ────────────────────────────────────────────────────────────────

    @Nested
    @DisplayName("update()")
    class Update {

        @Test
        @DisplayName("should update fields and raise ProductUpdatedEvent")
        void shouldUpdateFieldsAndRaiseEvent() {
            var product = ProductAggregate.create("Old", "desc", new BigDecimal("10.00"));
            product.clearEvents();

            product.update("New Name", "new desc", new BigDecimal("20.00"));

            assertThat(product.getName()).isEqualTo("New Name");
            assertThat(product.getPrice()).isEqualByComparingTo("20.00");
            assertThat(product.getDomainEvents()).hasSize(1);
        }
    }
}
