package com.example.productcatalog.common.constants;

/**
 * Centralised registry of Kafka topic names.
 *
 * <p>Consumers, producers, and the outbox poller all reference these constants
 * so topic names are defined once and never drift.
 */
public final class KafkaTopics {

    // ── Product events ────────────────────────────────────────────────────────
    public static final String PRODUCT_ADDED   = "product.added";
    public static final String PRODUCT_UPDATED = "product.updated";
    public static final String STOCK_CHANGED   = "product.stock.changed";

    // ── External topics ───────────────────────────────────────────────────────
    public static final String INVENTORY_SYNC  = "inventory.sync";

    private KafkaTopics() {}

    /**
     * Resolves the topic for a given event type string.
     * Falls back to a generic topic so no event is ever silently dropped.
     */
    public static String fromEventType(String eventType) {
        return switch (eventType) {
            case "ProductAdded"   -> PRODUCT_ADDED;
            case "ProductUpdated" -> PRODUCT_UPDATED;
            case "StockAdded",
                 "StockRemoved"   -> STOCK_CHANGED;
            default               -> "product.events";
        };
    }
}
