-- V1 — Initial schema

-- Products (write side aggregate store)
CREATE TABLE IF NOT EXISTS products (
    id               UUID         PRIMARY KEY,
    name             VARCHAR(255) NOT NULL,
    description      TEXT,
    price            NUMERIC(19,2) NOT NULL CHECK (price > 0),
    stock_quantity   INT          NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- Domain event log (append-only audit trail)
CREATE TABLE IF NOT EXISTS domain_events (
    event_id         UUID          PRIMARY KEY,
    aggregate_id     UUID          NOT NULL,
    aggregate_type   VARCHAR(100)  NOT NULL,
    event_type       VARCHAR(100)  NOT NULL,
    payload          TEXT          NOT NULL,
    occurred_at      TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- Outbox table (transactional outbox pattern)
CREATE TABLE IF NOT EXISTS outbox_events (
    id               UUID          PRIMARY KEY,
    aggregate_id     UUID          NOT NULL,
    event_type       VARCHAR(100)  NOT NULL,
    payload          TEXT          NOT NULL,
    published        BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP     NOT NULL DEFAULT NOW(),
    published_at     TIMESTAMP
);
