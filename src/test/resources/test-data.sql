-- Test fixture data — loaded by @Sql in integration tests

INSERT INTO products (id, name, description, price, stock_quantity, created_at, updated_at)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'Gaming Laptop',  'High-performance laptop', 1299.99, 50, NOW(), NOW()),
  ('22222222-2222-2222-2222-222222222222', 'Office Laptop',  'Business-grade laptop',   799.99,  30, NOW(), NOW()),
  ('33333333-3333-3333-3333-333333333333', 'Wireless Mouse', 'Ergonomic mouse',          29.99,   200,NOW(), NOW()),
  ('44444444-4444-4444-4444-444444444444', 'USB Hub',        '7-port USB 3.0 hub',       49.99,   0,  NOW(), NOW());
