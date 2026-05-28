-- V2 — Performance indexes

-- Products
CREATE INDEX IF NOT EXISTS idx_products_name       ON products (name);
CREATE INDEX IF NOT EXISTS idx_products_price      ON products (price);
CREATE INDEX IF NOT EXISTS idx_products_updated_at ON products (updated_at DESC);

-- Domain events
CREATE INDEX IF NOT EXISTS idx_domain_events_aggregate ON domain_events (aggregate_id, occurred_at ASC);
CREATE INDEX IF NOT EXISTS idx_domain_events_type      ON domain_events (event_type);

-- Outbox
CREATE INDEX IF NOT EXISTS idx_outbox_unpublished ON outbox_events (published, created_at ASC)
    WHERE published = FALSE;
