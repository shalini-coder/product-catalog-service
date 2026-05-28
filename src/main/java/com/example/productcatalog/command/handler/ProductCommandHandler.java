package com.example.productcatalog.command.handler;

import com.example.productcatalog.command.model.AddProductCommand;
import com.example.productcatalog.command.model.AddStockCommand;
import com.example.productcatalog.command.model.RemoveStockCommand;
import com.example.productcatalog.command.model.UpdateProductCommand;
import com.example.productcatalog.command.repository.DomainEventRepository;
import com.example.productcatalog.command.repository.OutboxRepository;
import com.example.productcatalog.command.repository.ProductRepository;
import com.example.productcatalog.common.util.JsonUtil;
import com.example.productcatalog.domain.exception.ProductNotFoundException;
import com.example.productcatalog.domain.model.ProductAggregate;
import com.example.productcatalog.event.model.DomainEvent;
import com.example.productcatalog.infrastructure.persistence.DomainEventEntity;
import com.example.productcatalog.infrastructure.persistence.OutboxEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProductCommandHandler {

    private final ProductRepository     productRepository;
    private final OutboxRepository      outboxRepository;
    private final DomainEventRepository domainEventRepository;
    private final JsonUtil              jsonUtil;

    // ── Commands ──────────────────────────────────────────────────────────────

    @Transactional(transactionManager = "transactionManager")
    public UUID handle(AddProductCommand command) {
        log.info("Handling AddProductCommand: name={}", command.getName());

        ProductAggregate product = ProductAggregate.create(
                command.getName(),
                command.getDescription(),
                command.getPrice());

        productRepository.save(product);
        saveEvents(product);

        log.info("Product created: id={}", product.getId());
        return product.getId();
    }

    @Transactional(transactionManager = "transactionManager")
    public void handle(UpdateProductCommand command) {
        log.info("Handling UpdateProductCommand: productId={}", command.getProductId());

        ProductAggregate product = loadOrThrow(command.getProductId());
        product.update(command.getName(), command.getDescription(), command.getPrice());

        productRepository.save(product);
        saveEvents(product);

        log.info("Product updated: id={}", command.getProductId());
    }

    @Transactional(transactionManager = "transactionManager")
    public void handle(AddStockCommand command) {
        log.info("Handling AddStockCommand: productId={}, qty={}", command.getProductId(), command.getQuantity());

        ProductAggregate product = loadOrThrow(command.getProductId());
        product.addStock(command.getQuantity());

        productRepository.save(product);
        saveEvents(product);

        log.info("Stock added: productId={}, newTotal={}", command.getProductId(), product.getStockQuantity());
    }

    @Transactional(transactionManager = "transactionManager")
    public void handle(RemoveStockCommand command) {
        log.info("Handling RemoveStockCommand: productId={}, qty={}", command.getProductId(), command.getQuantity());

        ProductAggregate product = loadOrThrow(command.getProductId());
        product.removeStock(command.getQuantity());

        productRepository.save(product);
        saveEvents(product);

        log.info("Stock removed: productId={}, newTotal={}", command.getProductId(), product.getStockQuantity());
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private ProductAggregate loadOrThrow(UUID productId) {
        return productRepository.findById(productId)
                .orElseThrow(() -> new ProductNotFoundException(productId));
    }

    /**
     * For each domain event raised by the aggregate:
     *  1. Writes to outbox_events  — picked up by OutboxPoller → Kafka (transient)
     *  2. Writes to domain_events  — permanent append-only audit log
     * Both writes are in the same transaction as the aggregate save.
     */
    private void saveEvents(ProductAggregate product) {
        for (DomainEvent event : product.getDomainEvents()) {
            String payload = jsonUtil.toJson(event);

            // 1. Outbox — for Kafka delivery
            OutboxEvent outbox = new OutboxEvent();
            outbox.setId(UUID.randomUUID());
            outbox.setEventType(event.getEventType());
            outbox.setAggregateId(product.getId());
            outbox.setPayload(payload);
            outbox.setPublished(false);
            outbox.setCreatedAt(LocalDateTime.now());
            outboxRepository.save(outbox);

            // 2. Audit log — permanent record of every event
            DomainEventEntity audit = new DomainEventEntity();
            audit.setEventId(event.getEventId());
            audit.setAggregateId(product.getId());
            audit.setAggregateType("Product");
            audit.setEventType(event.getEventType());
            audit.setPayload(payload);
            audit.setOccurredAt(event.getOccurredAt());
            domainEventRepository.save(audit);
        }
        product.clearEvents();
    }
}
