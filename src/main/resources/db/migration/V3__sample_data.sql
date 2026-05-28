-- V3 — Sample product data (seeded on first startup)
-- Covers a wide range of categories so CQRS search / filter queries are
-- immediately interesting when demoing the POC.

INSERT INTO products (id, name, description, price, stock_quantity, created_at, updated_at)
VALUES
    -- Electronics
    ('a1b2c3d4-0001-0000-0000-000000000001',
     'Gaming Laptop Pro 16"',
     'High-performance 16-inch gaming laptop — Intel Core i9, 32 GB RAM, RTX 4080, 1 TB NVMe SSD',
     1499.99, 25,
     NOW() - INTERVAL '30 days', NOW() - INTERVAL '2 days'),

    ('a1b2c3d4-0001-0000-0000-000000000002',
     'Wireless Noise-Cancelling Headphones',
     'Over-ear headphones with 40-hour battery life, active noise cancellation and hi-res audio',
     299.99, 80,
     NOW() - INTERVAL '25 days', NOW() - INTERVAL '3 days'),

    ('a1b2c3d4-0001-0000-0000-000000000003',
     '4K UHD Smart TV 55"',
     '55-inch 4K OLED smart TV with HDR10+, Dolby Vision, and built-in streaming apps',
     899.00, 15,
     NOW() - INTERVAL '20 days', NOW() - INTERVAL '1 day'),

    ('a1b2c3d4-0001-0000-0000-000000000004',
     'Mechanical Keyboard RGB',
     'TKL mechanical keyboard with Cherry MX Red switches, per-key RGB, USB-C detachable cable',
     139.99, 60,
     NOW() - INTERVAL '18 days', NOW() - INTERVAL '5 days'),

    -- Home & Kitchen
    ('a1b2c3d4-0001-0000-0000-000000000005',
     'Espresso Machine Barista Pro',
     'Semi-automatic 15-bar espresso machine with built-in grinder, steam wand and PID temperature control',
     549.00, 30,
     NOW() - INTERVAL '15 days', NOW() - INTERVAL '4 days'),

    ('a1b2c3d4-0001-0000-0000-000000000006',
     'Smart Air Purifier HEPA-13',
     'Wi-Fi air purifier — HEPA-13 filter, covers up to 600 sq ft, real-time air quality display',
     199.99, 45,
     NOW() - INTERVAL '12 days', NOW() - INTERVAL '6 days'),

    -- Sports & Fitness
    ('a1b2c3d4-0001-0000-0000-000000000007',
     'Adjustable Dumbbell Set 5-52 lb',
     'Space-saving adjustable dumbbell pair — dial to select weight in 2.5 lb increments up to 52 lb each',
     349.00, 20,
     NOW() - INTERVAL '10 days', NOW() - INTERVAL '1 day'),

    ('a1b2c3d4-0001-0000-0000-000000000008',
     'Smart Fitness Tracker Band',
     'Slim fitness band with heart-rate monitor, SpO2 sensor, sleep tracking, 14-day battery',
     79.99, 120,
     NOW() - INTERVAL '8 days', NOW() - INTERVAL '2 days'),

    -- Books / Learning
    ('a1b2c3d4-0001-0000-0000-000000000009',
     'Designing Data-Intensive Applications',
     'By Martin Kleppmann — the definitive guide to distributed systems, databases, and data engineering',
     44.99, 200,
     NOW() - INTERVAL '6 days', NOW() - INTERVAL '6 days'),

    -- Out-of-stock item (demonstrates inStock=false in Couchbase projection)
    ('a1b2c3d4-0001-0000-0000-000000000010',
     'Limited Edition Retro Console',
     'Classic 8-bit retro gaming console with 500 built-in games and two controllers included',
     129.99, 0,
     NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days')
ON CONFLICT (id) DO NOTHING;
