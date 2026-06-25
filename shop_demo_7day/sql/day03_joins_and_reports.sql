-- Day 3: joins and business reports.

USE shop_demo;

-- 1. INNER JOIN: order list with user info.
SELECT
  o.id,
  o.order_no,
  u.username,
  o.status,
  o.total_amount,
  o.created_at
FROM orders AS o
INNER JOIN users AS u ON u.id = o.user_id
ORDER BY o.created_at DESC;

-- 2. Order detail: order + items + product.
SELECT
  o.order_no,
  u.username,
  p.name AS product_name,
  oi.quantity,
  oi.unit_price,
  oi.quantity * oi.unit_price AS line_amount
FROM orders AS o
INNER JOIN users AS u ON u.id = o.user_id
INNER JOIN order_items AS oi ON oi.order_id = o.id
INNER JOIN products AS p ON p.id = oi.product_id
WHERE o.order_no = 'OD202606200001';

-- 3. LEFT JOIN: users who may have no orders.
SELECT
  u.id,
  u.username,
  COUNT(o.id) AS order_count,
  COALESCE(SUM(o.total_amount), 0) AS total_amount
FROM users AS u
LEFT JOIN orders AS o ON o.user_id = u.id
GROUP BY u.id, u.username
ORDER BY total_amount DESC;

-- 4. Products and inventory.
SELECT
  p.id,
  c.name AS category_name,
  p.name,
  p.status,
  i.stock,
  i.reserved_stock,
  i.stock - i.reserved_stock AS available_stock
FROM products AS p
INNER JOIN categories AS c ON c.id = p.category_id
INNER JOIN inventory AS i ON i.product_id = p.id
ORDER BY available_stock ASC, p.id;

-- 5. Sales by product.
SELECT
  p.id,
  p.name,
  SUM(oi.quantity) AS sold_quantity,
  SUM(oi.quantity * oi.unit_price) AS sales_amount
FROM order_items AS oi
INNER JOIN orders AS o ON o.id = oi.order_id
INNER JOIN products AS p ON p.id = oi.product_id
WHERE o.status = 'paid'
GROUP BY p.id, p.name
ORDER BY sales_amount DESC;

-- 6. Sales by category.
SELECT
  c.name AS category_name,
  SUM(oi.quantity) AS sold_quantity,
  SUM(oi.quantity * oi.unit_price) AS sales_amount
FROM categories AS c
INNER JOIN products AS p ON p.category_id = c.id
INNER JOIN order_items AS oi ON oi.product_id = p.id
INNER JOIN orders AS o ON o.id = oi.order_id
WHERE o.status = 'paid'
GROUP BY c.id, c.name
ORDER BY sales_amount DESC;

-- Exercises:
-- A. Find paid orders and their payment channel.
-- B. Find active users who have never paid an order.
-- C. Find products that have never appeared in a paid order.

SELECT
  o.order_no,
  u.username,
  p.channel,
  p.amount,
  p.paid_at
FROM payments AS p
INNER JOIN orders AS o ON o.id = p.order_id
INNER JOIN users AS u ON u.id = o.user_id
WHERE p.status = 'success';

SELECT u.id, u.username
FROM users AS u
LEFT JOIN orders AS o ON o.user_id = u.id AND o.status = 'paid'
WHERE u.status = 'active' AND o.id IS NULL;

SELECT p.id, p.name
FROM products AS p
LEFT JOIN order_items AS oi ON oi.product_id = p.id
LEFT JOIN orders AS o ON o.id = oi.order_id AND o.status = 'paid'
GROUP BY p.id, p.name
HAVING COUNT(o.id) = 0;

SELECT 'Day 3 finished: joins and business reports.' AS message;

