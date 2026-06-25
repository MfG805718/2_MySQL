-- Day 4: subqueries, CTEs, and window functions.

USE shop_demo;

-- 1. Scalar subquery: products above average price.
SELECT id, name, price
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC;

-- 2. IN subquery: users who have paid orders.
SELECT id, username
FROM users
WHERE id IN (
  SELECT user_id
  FROM orders
  WHERE status = 'paid'
);

-- 3. NOT EXISTS: users with no orders.
SELECT u.id, u.username
FROM users AS u
WHERE NOT EXISTS (
  SELECT 1
  FROM orders AS o
  WHERE o.user_id = u.id
);

-- 4. CTE: paid order totals per user.
WITH paid_orders AS (
  SELECT user_id, COUNT(*) AS order_count, SUM(total_amount) AS total_spent
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
)
SELECT u.username, po.order_count, po.total_spent
FROM paid_orders AS po
INNER JOIN users AS u ON u.id = po.user_id
ORDER BY po.total_spent DESC;

-- 5. Window function: rank products by paid sales amount.
WITH product_sales AS (
  SELECT
    p.id,
    p.name,
    COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS sales_amount
  FROM products AS p
  LEFT JOIN order_items AS oi ON oi.product_id = p.id
  LEFT JOIN orders AS o ON o.id = oi.order_id AND o.status = 'paid'
  GROUP BY p.id, p.name
)
SELECT
  id,
  name,
  sales_amount,
  RANK() OVER (ORDER BY sales_amount DESC) AS sales_rank
FROM product_sales;

-- 6. Latest order per user: classic "max per group" problem.
WITH ranked_orders AS (
  SELECT
    o.*,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC, id DESC) AS rn
  FROM orders AS o
)
SELECT
  u.username,
  ro.order_no,
  ro.status,
  ro.total_amount,
  ro.created_at
FROM ranked_orders AS ro
INNER JOIN users AS u ON u.id = ro.user_id
WHERE ro.rn = 1
ORDER BY ro.created_at DESC;

-- 7. Running total by day.
WITH daily_sales AS (
  SELECT DATE(created_at) AS sales_date, SUM(total_amount) AS daily_amount
  FROM orders
  WHERE status = 'paid'
  GROUP BY DATE(created_at)
)
SELECT
  sales_date,
  daily_amount,
  SUM(daily_amount) OVER (ORDER BY sales_date) AS running_amount
FROM daily_sales
ORDER BY sales_date;

-- Exercises:
-- A. Find each category's most expensive product.
-- B. Find each user's first order.
-- C. Rank users by paid total amount.

WITH ranked_products AS (
  SELECT
    p.*,
    ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC, id DESC) AS rn
  FROM products AS p
)
SELECT c.name AS category_name, rp.name AS product_name, rp.price
FROM ranked_products AS rp
INNER JOIN categories AS c ON c.id = rp.category_id
WHERE rp.rn = 1
ORDER BY c.id;

WITH first_orders AS (
  SELECT
    o.*,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at, id) AS rn
  FROM orders AS o
)
SELECT u.username, fo.order_no, fo.created_at
FROM first_orders AS fo
INNER JOIN users AS u ON u.id = fo.user_id
WHERE fo.rn = 1;

WITH user_paid_amount AS (
  SELECT user_id, SUM(total_amount) AS paid_amount
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
)
SELECT
  u.username,
  upa.paid_amount,
  DENSE_RANK() OVER (ORDER BY upa.paid_amount DESC) AS paid_rank
FROM user_paid_amount AS upa
INNER JOIN users AS u ON u.id = upa.user_id;

SELECT 'Day 4 finished: subqueries, CTEs, window functions, and max-per-group queries.' AS message;

