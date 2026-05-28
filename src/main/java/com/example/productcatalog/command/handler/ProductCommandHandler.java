package com.example.productcatalog.command.handler;

import com.example.productcatalog.command.model.AddProductCommand;
import com.example.productcatalog.command.model.AddStockCommand;
import com.example.productcatalog.command.model.RemoveStockCommand;
import com.example.productcatalog.command.model.UpdateProductCommand;
import com.example.productcatalog.command.repository.OutboxRepository;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.domain.exception.ProductNotFoundException;
import com.example.productcatalog.domain.model.ProductAggregate;
import com.example.productcatalog.event.model.DomainEvent;
import com.example.productcatalog.infrastructure.persistence.OutboxEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Application-layer service that executes all product write commands.
 *
 * <p>Each method is a single transactional unit: it loads the aggregate,
 * applies the domain operation, persists changes, and saves domain events
 * to the outbox table — all within one transaction.
 *
 * <p>Constructor injection is used throughout; no field {@code @Autowired}.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ProductCommandHandler {

    private final ProductRepository    productRepository;
    private final OutboxRepository     outboxRepository;
    private final JsonUtil             jsonUtil;

    // ── Commands ──────────────────────────────────────────────────────────────

    @Transactional
    public UUID handle(AddProductCommand command) {
        log.info("Handling AddProductCommand: name={}", command.getName());

        ProductAggregate product = ProductAggregate.create(
                command.getName(),
                command.getDescription(),
                command.getPrice());

        productRepository.save(product);
        saveToOutbox(product);

        log.info("Product created: id={}", product.getId());
        return product.getId();
    }

    @Transactional
    public void handle(UpdateProductCommand command) {
        log.info("Handling UpdateProductCommand: productId={}", command.getProductId());

        ProductAggregate product = loadOrThrow(command.getProductId());

        product.update(command.getName(), command.getDescription(), command.getPrice());

        productRepository.save(product);
        saveToOutbox(product);

        log.info("Product updated: id={}", command.getProductId());
    }

    @Transactional
    public void handle(AddStockCommand command) {
        log.info("Handling AddStockCommand: productId={}, qty={}", command.getProductId(), command.getQuantity());

        ProductAggregate product = loadOrThrow(command.getProductId());

        product.addStock(command.getQuantity());

        productRepository.save(product);
        saveToOutbox(product);

        log.info("Stock added: productId={}, newTotal={}", command.getProductId(), product.getStockQuantity());
    }

    @Transactional
    public void handle(RemoveStockCommand command) {
        log.info("Handling RemoveStockCommand: productId={}, qty={}", command.getProductId(), command.getQuantity());

        ProductAggregate product = loadOrThrow(command.getProductId());

        product.removeStock(command.getQuantity());

        productRepository.save(product);
        saveToOutbox(product);

        log.info("Stock removed: productId={}, newTotal={}", command.getProductId(), product.getStockQuantity());
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private ProductAggregate loadOrThrow(UUID productId) {
        return productRepository.findById(productId)
                .orElseThrow(() -> new ProductNotFoundException(productId));
    }

    /**
     * Saves raised domain events to the outbox table within the same transaction.
     * The {@link com.example.productcatalog.infrastructure.persistence.OutboxPoller}
     * reads them and publishes to Kafka asynchronously.
     */
    private void saveToOutbox(ProductAggregate product) {
        for (DomainEvent event : product.getDomainEvents()) {
            OutboxEvent outboxEvent = new OutboxEvent();
            outboxEvent.setId(UUID.randomUUID());
            outboxEvent.setEventType(event.getEventType());
            outboxEvent.setAggregateId(product.getId());
            outboxEvent.setPayload(jsonUtil.toJson(event));
            outboxEvent.setPublished(false);
            outboxEvent.setCreatedAt(LocalDateTime.now());
            outboxRepository.save(outboxEvent);
        }
        product.clearEvents();
    }
}
