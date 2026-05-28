package com.example.productcatalog.domain.model;

import com.example.productcatalog.domain.exception.InsufficientStockException;
import com.example.productcatalog.event.model.DomainEvent;
import com.example.productcatalog.event.model.ProductAddedEvent;
import com.example.productcatalog.event.model.ProductUpdatedEvent;
import com.example.productcatalog.event.model.StockAddedEvent;
import com.example.productcatalog.event.model.StockRemovedEvent;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Transient;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * Aggregate root for the Product domain.
 *
 * <p>All state changes go through this class, which enforces invariants
 * and records domain events. JPA annotations are limited to mapping
 * concerns — domain logic remains free of persistence framework details.
 *
 * <p>Value objects ({@link Money}, {@link StockInfo}) are used for
 * in-memory validation but their scalar values are persisted directly
 * so that Hibernate can map them without @Embeddable complexity.
 */
@Entity
@Table(name = "products")
public class ProductAggregate {

    @Id
    @Column(name = "id", updatable = false, nullable = false)
    private UUID id;

    @Column(name = "name", nullable = false, length = 255)
    private String name;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    /** Stored as the plain scalar; use {@link Money} for domain validation. */
    @Column(name = "price", nullable = false, precision = 19, scale = 2)
    private BigDecimal price;

    /** Stored as the plain scalar; invariants enforced by this aggregate. */
    @Column(name = "stock_quantity", nullable = false)
    private int stockQuantity;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    /** Not persisted — cleared after every transaction. */
    @Transient
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    // ── Protected no-arg constructor required by JPA ──────────────────────────
    protected ProductAggregate() {}

    // ── Private constructor (use factory method) ──────────────────────────────
    private ProductAggregate(UUID id, String name, String description, BigDecimal price) {
        this.id            = id;
        this.name          = name;
        this.description   = description;
        this.price         = price.setScale(2, RoundingMode.HALF_UP);
        this.stockQuantity = 0;
        this.createdAt     = LocalDateTime.now();
        this.updatedAt     = LocalDateTime.now();
    }

    // ── Factory ───────────────────────────────────────────────────────────────

    /**
     * Creates a new product and raises a {@link ProductAddedEvent}.
     */
    public static ProductAggregate create(String name, String description, BigDecimal price) {
        validateName(name);
        validatePrice(price);

        UUID id = UUID.randomUUID();
        ProductAggregate product = new ProductAggregate(id, name, description, price);
        product.raiseEvent(new ProductAddedEvent(id, name, description, price, LocalDateTime.now()));
        return product;
    }

    // ── Commands ──────────────────────────────────────────────────────────────

    /**
     * Updates the product's mutable attributes and raises a {@link ProductUpdatedEvent}.
     */
    public void update(String name, String description, BigDecimal price) {
        validateName(name);
        validatePrice(price);

        this.name        = name;
        this.description = description;
        this.price       = price.setScale(2, RoundingMode.HALF_UP);
        this.updatedAt   = LocalDateTime.now();

        raiseEvent(new ProductUpdatedEvent(this.id, name, description, price, LocalDateTime.now()));
    }

    /**
     * Increases stock quantity and raises a {@link StockAddedEvent}.
     */
    public void addStock(int quantity) {
        if (quantity <= 0) {
            throw new IllegalArgumentException("Quantity to add must be positive, got: " + quantity);
        }
        this.stockQuantity += quantity;
        this.updatedAt      = LocalDateTime.now();

        raiseEvent(new StockAddedEvent(this.id, quantity, this.stockQuantity, LocalDateTime.now()));
    }

    /**
     * Decreases stock quantity (enforces no-overdraft rule) and raises a {@link StockRemovedEvent}.
     */
    public void removeStock(int quantity) {
        if (quantity <= 0) {
            throw new IllegalArgumentException("Quantity to remove must be positive, got: " + quantity);
        }
        if (quantity > this.stockQuantity) {
            throw new InsufficientStockException(this.id, this.stockQuantity, quantity);
        }
        this.stockQuantity -= quantity;
        this.updatedAt      = LocalDateTime.now();

        raiseEvent(new StockRemovedEvent(this.id, quantity, this.stockQuantity, LocalDateTime.now()));
    }

    // ── Event helpers ─────────────────────────────────────────────────────────

    private void raiseEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    public List<DomainEvent> getDomainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    public void clearEvents() {
        domainEvents.clear();
    }

    // ── Queries ───────────────────────────────────────────────────────────────

    public boolean isInStock() {
        return stockQuantity > 0;
    }

    // ── Getters (read-only; no public setters on the aggregate) ──────────────

    public UUID getId()                { return id; }
    public String getName()            { return name; }
    public String getDescription()     { return description; }
    public BigDecimal getPrice()       { return price; }
    public int getStockQuantity()      { return stockQuantity; }
    public LocalDateTime getCreatedAt(){ return createdAt; }
    public LocalDateTime getUpdatedAt(){ return updatedAt; }

    // ── Private validation ────────────────────────────────────────────────────

    private static void validateName(String name) {
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("Product name cannot be blank");
        }
    }

    private static void validatePrice(BigDecimal price) {
        if (price == null || price.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Price must be greater than zero");
        }
    }
}
