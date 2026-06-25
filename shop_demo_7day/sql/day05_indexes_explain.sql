-- Day 5: indexes and EXPLAIN.

USE shop_demo;

-- 1. Inspect existing indexes.
SHOW INDEX FROM users;
SHOW INDEX FROM orders;
SHOW INDEX FROM order_items;
SHOW INDEX FROM products;

-- 2. EXPLAIN a common order-list query.
EXPLAIN
SELECT id, order_no, user_id, status, total_amount, created_at
FROM orders
WHERE user_id = 1
ORDER BY created_at DESC
LIMIT 10;

-- 3. EXPLAIN a status dashboard query.
EXPLAIN
SELECT id, order_no, status, total_amount, created_at
FROM orders
WHERE status = 'paid'
ORDER BY created_at DESC;

-- 4. Add an index for active product browsing.
CREATE INDEX idx_products_status_price_id ON products(status, price, id);

EXPLAIN
SELECT id, name, price
FROM products
WHERE status = 'active' AND price BETWEEN 50 AND 200
ORDER BY price, id
LIMIT 10;

-- 5. Leftmost prefix demo.
-- This can use idx_products_status_price_id well.
EXPLAIN
SELECT id, name, price
FROM products
WHERE status = 'active'
ORDER BY price, id;

-- This may not use the same index as efficiently because status is skipped.
EXPLAIN
SELECT id, name, price
FROM products
WHERE price BETWEEN 50 AND 200
ORDER BY price, id;

-- 6. Avoid wrapping indexed columns in functions when filtering.
-- Less friendly to an index on created_at:
EXPLAIN
SELECT id, order_no, created_at
FROM orders
WHERE DATE(created_at) = '2026-06-20';

-- More index-friendly:
EXPLAIN
SELECT id, order_no, created_at
FROM orders
WHERE created_at >= '2026-06-20' AND created_at < '2026-06-21';

-- 7. Add a useful reporting index for order_items aggregation by product.
CREATE INDEX idx_order_items_product_order ON order_items(product_id, order_id);

EXPLAIN
SELECT
  p.id,
  p.name,
  SUM(oi.quantity) AS sold_quantity
FROM products AS p
INNER JOIN order_items AS oi ON oi.product_id = p.id
INNER JOIN orders AS o ON o.id = oi.order_id
WHERE o.status = 'paid'
GROUP BY p.id, p.name;

-- Exercises:
-- A. Explain the query: paid orders by user, newest first.
-- B. Create an index if the query shape is common.
-- C. Use SHOW INDEX again and describe which columns each index starts with.

EXPLAIN
SELECT id, order_no, total_amount, created_at
FROM orders
WHERE user_id = 2 AND status = 'paid'
ORDER BY created_at DESC;

CREATE INDEX idx_orders_user_status_created ON orders(user_id, status, created_at);

SHOW INDEX FROM orders;

SELECT 'Day 5 finished: indexes, leftmost prefix, and EXPLAIN basics.' AS message;

