-- Day 1: schema design and seed data.
-- This file resets the practice database.

DROP DATABASE IF EXISTS shop_demo;
CREATE DATABASE shop_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE shop_demo;

CREATE TABLE users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  email VARCHAR(100) NOT NULL,
  phone VARCHAR(30),
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_users_username (username),
  UNIQUE KEY uk_users_email (email)
) ENGINE=InnoDB;

CREATE TABLE categories (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL,
  UNIQUE KEY uk_categories_name (name)
) ENGINE=InnoDB;

CREATE TABLE products (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id BIGINT NOT NULL,
  name VARCHAR(100) NOT NULL,
  sku VARCHAR(50) NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_products_sku (sku),
  KEY idx_products_category (category_id),
  CONSTRAINT fk_products_category
    FOREIGN KEY (category_id) REFERENCES categories(id)
) ENGINE=InnoDB;

CREATE TABLE inventory (
  product_id BIGINT PRIMARY KEY,
  stock INT NOT NULL DEFAULT 0,
  reserved_stock INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_inventory_product
    FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT chk_inventory_stock
    CHECK (stock >= 0 AND reserved_stock >= 0 AND reserved_stock <= stock)
) ENGINE=InnoDB;

CREATE TABLE orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_no VARCHAR(32) NOT NULL,
  user_id BIGINT NOT NULL,
  total_amount DECIMAL(10,2) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'created',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_at TIMESTAMP NULL,
  UNIQUE KEY uk_orders_order_no (order_no),
  KEY idx_orders_user_created (user_id, created_at),
  KEY idx_orders_status_created (status, created_at),
  CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;

CREATE TABLE order_items (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  KEY idx_order_items_order (order_id),
  KEY idx_order_items_product (product_id),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id),
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(id),
  CONSTRAINT chk_order_items_quantity
    CHECK (quantity > 0)
) ENGINE=InnoDB;

CREATE TABLE payments (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  payment_no VARCHAR(32) NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  channel VARCHAR(20) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'success',
  paid_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_payments_payment_no (payment_no),
  UNIQUE KEY uk_payments_order_success (order_id, status),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
) ENGINE=InnoDB;

CREATE TABLE operation_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  actor VARCHAR(50) NOT NULL,
  action VARCHAR(50) NOT NULL,
  target_type VARCHAR(50) NOT NULL,
  target_id BIGINT NOT NULL,
  detail VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_logs_target (target_type, target_id),
  KEY idx_logs_created (created_at)
) ENGINE=InnoDB;

INSERT INTO users (username, email, phone, status, created_at) VALUES
('alice', 'alice@example.com', '13800000001', 'active', '2026-06-18 09:00:00'),
('bob', 'bob@example.com', '13800000002', 'active', '2026-06-19 10:00:00'),
('carol', 'carol@example.com', '13800000003', 'active', '2026-06-20 11:00:00'),
('dave', 'dave@example.com', '13800000004', 'locked', '2026-06-21 12:00:00'),
('erin', 'erin@example.com', '13800000005', 'active', '2026-06-22 13:00:00');

INSERT INTO categories (name) VALUES
('Books'), ('Electronics'), ('Office'), ('Food');

INSERT INTO products (category_id, name, sku, price, status, created_at) VALUES
(1, 'MySQL Pocket Guide', 'BOOK-MYSQL-001', 49.00, 'active', '2026-06-18 09:05:00'),
(1, 'Database Design Notes', 'BOOK-DB-002', 69.00, 'active', '2026-06-18 09:06:00'),
(2, 'USB-C Hub', 'ELEC-HUB-001', 129.00, 'active', '2026-06-19 10:05:00'),
(2, 'Mechanical Keyboard', 'ELEC-KEY-002', 399.00, 'active', '2026-06-19 10:06:00'),
(3, 'Notebook Pack', 'OFF-NOTE-001', 29.90, 'active', '2026-06-20 11:05:00'),
(3, 'Standing Desk Mat', 'OFF-MAT-002', 89.00, 'inactive', '2026-06-20 11:06:00'),
(4, 'Coffee Beans', 'FOOD-COF-001', 79.00, 'active', '2026-06-21 12:05:00');

INSERT INTO inventory (product_id, stock, reserved_stock) VALUES
(1, 120, 0), (2, 80, 0), (3, 45, 2), (4, 20, 1),
(5, 300, 0), (6, 0, 0), (7, 60, 0);

INSERT INTO orders (order_no, user_id, total_amount, status, created_at, paid_at) VALUES
('OD202606180001', 1, 118.00, 'paid', '2026-06-18 14:00:00', '2026-06-18 14:05:00'),
('OD202606190001', 2, 129.00, 'paid', '2026-06-19 15:00:00', '2026-06-19 15:03:00'),
('OD202606200001', 1, 478.00, 'paid', '2026-06-20 16:00:00', '2026-06-20 16:10:00'),
('OD202606210001', 3, 29.90, 'created', '2026-06-21 17:00:00', NULL),
('OD202606220001', 2, 79.00, 'cancelled', '2026-06-22 18:00:00', NULL),
('OD202606230001', 5, 158.00, 'paid', '2026-06-23 19:00:00', '2026-06-23 19:08:00');

INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 49.00), (1, 2, 1, 69.00),
(2, 3, 1, 129.00),
(3, 4, 1, 399.00), (3, 7, 1, 79.00),
(4, 5, 1, 29.90),
(5, 7, 1, 79.00),
(6, 7, 2, 79.00);

INSERT INTO payments (order_id, payment_no, amount, channel, status, paid_at) VALUES
(1, 'PAY202606180001', 118.00, 'wechat', 'success', '2026-06-18 14:05:00'),
(2, 'PAY202606190001', 129.00, 'alipay', 'success', '2026-06-19 15:03:00'),
(3, 'PAY202606200001', 478.00, 'card', 'success', '2026-06-20 16:10:00'),
(6, 'PAY202606230001', 158.00, 'wechat', 'success', '2026-06-23 19:08:00');

INSERT INTO operation_logs (actor, action, target_type, target_id, detail, created_at) VALUES
('system', 'create_order', 'orders', 1, 'alice placed order', '2026-06-18 14:00:00'),
('system', 'pay_order', 'orders', 1, 'payment success', '2026-06-18 14:05:00'),
('admin', 'disable_product', 'products', 6, 'temporary out of stock', '2026-06-22 09:00:00');

SHOW TABLES;
SELECT 'Day 1 finished: schema and seed data are ready.' AS message;

