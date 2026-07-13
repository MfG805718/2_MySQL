-- Day 1: create a small operations database for CRUD practice.
-- WARNING: This resets only the practice database ops_demo.

DROP DATABASE IF EXISTS ops_demo;
CREATE DATABASE ops_demo CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE ops_demo;

CREATE TABLE customers (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  email VARCHAR(120) NOT NULL,
  phone VARCHAR(30),
  company VARCHAR(100),
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_customers_email (email),
  KEY idx_customers_status_created (status, created_at)
) ENGINE=InnoDB;

CREATE TABLE agents (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(80) NOT NULL,
  email VARCHAR(120) NOT NULL,
  team VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  UNIQUE KEY uk_agents_email (email)
) ENGINE=InnoDB;

CREATE TABLE tickets (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  ticket_no VARCHAR(32) NOT NULL,
  customer_id BIGINT NOT NULL,
  assigned_agent_id BIGINT NULL,
  title VARCHAR(160) NOT NULL,
  priority VARCHAR(20) NOT NULL DEFAULT 'normal',
  status VARCHAR(20) NOT NULL DEFAULT 'open',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  closed_at TIMESTAMP NULL,
  UNIQUE KEY uk_tickets_ticket_no (ticket_no),
  KEY idx_tickets_customer_created (customer_id, created_at),
  KEY idx_tickets_agent_status (assigned_agent_id, status),
  KEY idx_tickets_status_priority (status, priority),
  CONSTRAINT fk_tickets_customer
    FOREIGN KEY (customer_id) REFERENCES customers(id),
  CONSTRAINT fk_tickets_agent
    FOREIGN KEY (assigned_agent_id) REFERENCES agents(id)
) ENGINE=InnoDB;

CREATE TABLE ticket_comments (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  ticket_id BIGINT NOT NULL,
  author_type VARCHAR(20) NOT NULL,
  author_name VARCHAR(80) NOT NULL,
  body VARCHAR(500) NOT NULL,
  is_internal TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_comments_ticket_created (ticket_id, created_at),
  CONSTRAINT fk_comments_ticket
    FOREIGN KEY (ticket_id) REFERENCES tickets(id)
) ENGINE=InnoDB;

CREATE TABLE audit_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  actor VARCHAR(80) NOT NULL,
  action VARCHAR(50) NOT NULL,
  target_table VARCHAR(50) NOT NULL,
  target_id BIGINT NOT NULL,
  detail VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_audit_target (target_table, target_id),
  KEY idx_audit_created (created_at)
) ENGINE=InnoDB;

INSERT INTO customers (name, email, phone, company, status, created_at) VALUES
('Alice Chen', 'alice.chen@example.com', '13800001001', 'Northwind Labs', 'active', '2026-07-01 09:00:00'),
('Bob Li', 'bob.li@example.com', '13800001002', 'River Tech', 'active', '2026-07-02 10:00:00'),
('Carol Wang', 'carol.wang@example.com', '13800001003', 'Beacon Studio', 'active', '2026-07-03 11:00:00'),
('Dave Zhao', 'dave.zhao@example.com', '13800001004', 'Old Star LLC', 'inactive', '2026-07-04 12:00:00');

INSERT INTO agents (name, email, team, status) VALUES
('Mina Support', 'mina.support@example.com', 'support', 'active'),
('Leo Ops', 'leo.ops@example.com', 'operations', 'active'),
('Nora QA', 'nora.qa@example.com', 'quality', 'active');

INSERT INTO tickets (ticket_no, customer_id, assigned_agent_id, title, priority, status, created_at, closed_at) VALUES
('TK202607010001', 1, 1, 'Cannot log in to dashboard', 'high', 'open', '2026-07-01 09:30:00', NULL),
('TK202607020001', 2, 1, 'Invoice amount looks wrong', 'normal', 'pending', '2026-07-02 10:30:00', NULL),
('TK202607030001', 3, 2, 'Need to update company address', 'low', 'closed', '2026-07-03 11:30:00', '2026-07-03 15:00:00'),
('TK202607040001', 1, NULL, 'Feature request for export', 'normal', 'open', '2026-07-04 12:30:00', NULL);

INSERT INTO ticket_comments (ticket_id, author_type, author_name, body, is_internal, created_at) VALUES
(1, 'customer', 'Alice Chen', 'I cannot log in after resetting my password.', 0, '2026-07-01 09:31:00'),
(1, 'agent', 'Mina Support', 'Asked customer to provide browser version.', 1, '2026-07-01 09:40:00'),
(2, 'customer', 'Bob Li', 'The invoice total is 200 higher than expected.', 0, '2026-07-02 10:31:00'),
(3, 'agent', 'Leo Ops', 'Address was updated and verified.', 0, '2026-07-03 14:59:00');

INSERT INTO audit_logs (actor, action, target_table, target_id, detail, created_at) VALUES
('system', 'create_ticket', 'tickets', 1, 'customer created login ticket', '2026-07-01 09:30:00'),
('system', 'create_ticket', 'tickets', 2, 'customer created invoice ticket', '2026-07-02 10:30:00'),
('leo.ops', 'close_ticket', 'tickets', 3, 'address update completed', '2026-07-03 15:00:00');

SHOW TABLES;
SELECT 'Day 1 finished: ops_demo schema and seed data are ready.' AS message;

