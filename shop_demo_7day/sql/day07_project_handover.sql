-- Day 7: project handover simulation.

USE shop_demo;

-- 1. First 10 minutes after receiving a database.
SHOW TABLES;
SHOW CREATE TABLE orders;
SHOW CREATE TABLE order_items;
SHOW INDEX FROM orders;
SHOW INDEX FROM products;

-- 2. Data scale overview.
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'operation_logs', COUNT(*) FROM operation_logs;

-- 3. Health checks.
SELECT p.id, p.name
FROM products AS p
LEFT JOIN inventory AS i ON i.product_id = p.id
WHERE i.product_id IS NULL;

SELECT i.product_id, p.name, i.stock, i.reserved_stock
FROM inventory AS i
INNER JOIN products AS p ON p.id = i.product_id
WHERE i.reserved_stock > i.stock;

SELECT o.id, o.order_no, o.status, o.total_amount, COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS item_amount
FROM orders AS o
LEFT JOIN order_items AS oi ON oi.order_id = o.id
GROUP BY o.id, o.order_no, o.status, o.total_amount
HAVING ABS(o.total_amount - item_amount) > 0.001;

-- 4. Core business queries you should be able to write quickly.
-- Order list page.
SELECT
  o.id,
  o.order_no,
  u.username,
  o.status,
  o.total_amount,
  o.created_at
FROM orders AS o
INNER JOIN users AS u ON u.id = o.user_id
ORDER BY o.created_at DESC
LIMIT 20;

-- Order detail page.
SELECT
  o.order_no,
  o.status,
  u.username,
  p.name AS product_name,
  oi.quantity,
  oi.unit_price,
  oi.quantity * oi.unit_price AS line_amount
FROM orders AS o
INNER JOIN users AS u ON u.id = o.user_id
INNER JOIN order_items AS oi ON oi.order_id = o.id
INNER JOIN products AS p ON p.id = oi.product_id
WHERE o.order_no = 'OD202606240001';

-- Daily paid sales.
SELECT
  DATE(paid_at) AS sales_date,
  COUNT(*) AS paid_order_count,
  SUM(total_amount) AS paid_amount
FROM orders
WHERE status = 'paid'
GROUP BY DATE(paid_at)
ORDER BY sales_date;

-- Low stock alert.
SELECT
  p.id,
  p.name,
  i.stock,
  i.reserved_stock,
  i.stock - i.reserved_stock AS available_stock
FROM inventory AS i
INNER JOIN products AS p ON p.id = i.product_id
WHERE i.stock - i.reserved_stock < 10
ORDER BY available_stock, p.id;

-- Latest order per user.
WITH ranked_orders AS (
  SELECT
    o.*,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC, id DESC) AS rn
  FROM orders AS o
)
SELECT u.username, ro.order_no, ro.status, ro.total_amount, ro.created_at
FROM ranked_orders AS ro
INNER JOIN users AS u ON u.id = ro.user_id
WHERE ro.rn = 1
ORDER BY ro.created_at DESC;

-- 5. Explain high-frequency queries before changing indexes.
EXPLAIN
SELECT id, order_no, total_amount, created_at
FROM orders
WHERE user_id = 1 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 10;

EXPLAIN
SELECT id, name, price
FROM products
WHERE status = 'active' AND price BETWEEN 50 AND 200
ORDER BY price, id
LIMIT 10;

-- 6. Final handover questions.
-- Answer these in your own notes:
-- A. Which table owns order status?
-- B. Which unique keys prevent duplicate users, duplicate orders, and duplicate payments?
-- C. Which query would slow down first if orders grew from 10 rows to 10 million rows?
-- D. Which writes must be wrapped in a transaction?
-- E. Which indexes support the order list page and product browsing page?

SELECT 'Day 7 finished: you have completed the shop_demo handover simulation.' AS message;

