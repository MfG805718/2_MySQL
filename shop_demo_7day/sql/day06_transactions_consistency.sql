-- Day 6: transactions, rollback, and consistency.

USE shop_demo;

-- 1. Observe current inventory.
SELECT p.id, p.name, i.stock, i.reserved_stock, i.stock - i.reserved_stock AS available_stock
FROM products AS p
INNER JOIN inventory AS i ON i.product_id = p.id
ORDER BY p.id;

-- 2. Rollback demo: this order should disappear.
START TRANSACTION;

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_ROLLBACK_DEMO', 1, 49.00, 'created');

SELECT id, order_no, status FROM orders WHERE order_no = 'OD_ROLLBACK_DEMO';

ROLLBACK;

SELECT id, order_no, status FROM orders WHERE order_no = 'OD_ROLLBACK_DEMO';

-- 3. Commit demo: create a real order and one item.
START TRANSACTION;

UPDATE inventory
SET reserved_stock = reserved_stock + 1
WHERE product_id = 1 AND stock - reserved_stock >= 1;

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD202606240001', 3, 49.00, 'created');

SET @new_order_id = LAST_INSERT_ID();

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (@new_order_id, 1, 1, 49.00);

INSERT INTO operation_logs (actor, action, target_type, target_id, detail)
VALUES ('system', 'create_order', 'orders', @new_order_id, 'transaction commit demo');

COMMIT;

SELECT id, order_no, user_id, total_amount, status
FROM orders
WHERE order_no = 'OD202606240001';

SELECT product_id, stock, reserved_stock, stock - reserved_stock AS available_stock
FROM inventory
WHERE product_id = 1;

-- 4. Payment transaction: mark order paid, reduce real stock, release reserved stock.
START TRANSACTION;

SELECT product_id, stock, reserved_stock
FROM inventory
WHERE product_id = 1
FOR UPDATE;

UPDATE orders
SET status = 'paid', paid_at = CURRENT_TIMESTAMP
WHERE order_no = 'OD202606240001' AND status = 'created';

UPDATE inventory
SET stock = stock - 1,
    reserved_stock = reserved_stock - 1
WHERE product_id = 1 AND reserved_stock >= 1;

INSERT INTO payments (order_id, payment_no, amount, channel, status)
SELECT id, 'PAY202606240001', total_amount, 'wechat', 'success'
FROM orders
WHERE order_no = 'OD202606240001';

INSERT INTO operation_logs (actor, action, target_type, target_id, detail)
SELECT 'system', 'pay_order', 'orders', id, 'payment transaction demo'
FROM orders
WHERE order_no = 'OD202606240001';

COMMIT;

SELECT o.order_no, o.status, o.paid_at, p.payment_no, p.amount, p.channel
FROM orders AS o
LEFT JOIN payments AS p ON p.order_id = o.id
WHERE o.order_no = 'OD202606240001';

-- 5. Constraint demo: uncomment one block at a time to see failures.
-- Duplicate order_no should fail:
-- INSERT INTO orders (order_no, user_id, total_amount, status)
-- VALUES ('OD202606240001', 1, 10.00, 'created');

-- Invalid foreign key should fail:
-- INSERT INTO orders (order_no, user_id, total_amount, status)
-- VALUES ('OD_BAD_USER', 999999, 10.00, 'created');

-- Invalid inventory should fail because reserved_stock cannot exceed stock:
-- UPDATE inventory SET reserved_stock = stock + 1 WHERE product_id = 1;

-- Exercises:
-- A. Create a cancelled-order transaction that releases reserved stock.
-- B. Try paying the same order twice and observe the unique payment constraint.
-- C. Explain why SELECT ... FOR UPDATE matters for inventory.

SELECT 'Day 6 finished: transactions, rollback, commit, inventory consistency, and constraints.' AS message;

