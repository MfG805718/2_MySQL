-- Day 2: basic query practice.

USE shop_demo;

-- 1. Inspect table shape.
DESC users;
DESC products;

-- 2. Read all columns, then read selected columns.
SELECT * FROM users;
SELECT id, username, email, status, created_at FROM users;

-- 3. WHERE filters.
SELECT id, username, status
FROM users
WHERE status = 'active';

SELECT id, name, price
FROM products
WHERE price BETWEEN 50 AND 150;

SELECT id, name, sku
FROM products
WHERE sku LIKE 'ELEC%';

SELECT id, name, status
FROM products
WHERE status IN ('active', 'inactive');

-- 4. ORDER BY and LIMIT.
SELECT id, name, price
FROM products
WHERE status = 'active'
ORDER BY price DESC
LIMIT 3;

-- 5. Pagination pattern: page 2, page size 2.
SELECT id, name, price
FROM products
ORDER BY id
LIMIT 2 OFFSET 2;

-- 6. Aggregate functions.
SELECT COUNT(*) AS user_count FROM users;
SELECT COUNT(*) AS active_product_count FROM products WHERE status = 'active';
SELECT MIN(price) AS min_price, MAX(price) AS max_price, AVG(price) AS avg_price FROM products;

-- 7. GROUP BY.
SELECT status, COUNT(*) AS order_count, SUM(total_amount) AS total_amount
FROM orders
GROUP BY status;

SELECT DATE(created_at) AS order_date, COUNT(*) AS order_count, SUM(total_amount) AS total_amount
FROM orders
GROUP BY DATE(created_at)
ORDER BY order_date;

-- 8. HAVING filters grouped results.
SELECT user_id, COUNT(*) AS order_count, SUM(total_amount) AS total_spent
FROM orders
GROUP BY user_id
HAVING SUM(total_amount) >= 150;

-- Exercises:
-- A. Find active products whose price is lower than 100.
-- B. Count orders created from 2026-06-20 to 2026-06-23.
-- C. Find the top 2 users by total order amount.

SELECT id, name, price
FROM products
WHERE status = 'active' AND price < 100
ORDER BY price;

SELECT COUNT(*) AS order_count
FROM orders
WHERE created_at >= '2026-06-20' AND created_at < '2026-06-24';

SELECT user_id, SUM(total_amount) AS total_spent
FROM orders
GROUP BY user_id
ORDER BY total_spent DESC
LIMIT 2;

SELECT 'Day 2 finished: basic queries, filters, sorting, pagination, and grouping.' AS message;

