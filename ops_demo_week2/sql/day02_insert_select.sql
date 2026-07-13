-- Day 2: INSERT and SELECT.

USE ops_demo;

-- 1. Basic INSERT.
INSERT INTO customers (name, email, phone, company)
VALUES ('Erin Sun', 'erin.sun@example.com', '13800001005', 'Future Works');

INSERT INTO tickets (ticket_no, customer_id, assigned_agent_id, title, priority, status)
VALUES ('TK202607050001', 5, 2, 'Need help with account setup', 'normal', 'open');

INSERT INTO ticket_comments (ticket_id, author_type, author_name, body, is_internal)
VALUES (5, 'customer', 'Erin Sun', 'Please help us finish account setup this week.', 0);

-- 2. INSERT multiple rows.
INSERT INTO audit_logs (actor, action, target_table, target_id, detail) VALUES
('system', 'create_customer', 'customers', 5, 'new customer from day 2 practice'),
('system', 'create_ticket', 'tickets', 5, 'new setup ticket from day 2 practice');

-- 3. Basic SELECT.
SELECT id, name, email, company, status
FROM customers
ORDER BY id;

-- 4. Filtering.
SELECT id, ticket_no, title, priority, status
FROM tickets
WHERE status = 'open'
ORDER BY created_at DESC;

SELECT id, name, email
FROM customers
WHERE email LIKE '%example.com';

SELECT id, ticket_no, priority, status
FROM tickets
WHERE priority IN ('high', 'normal') AND status <> 'closed';

-- 5. Pagination.
SELECT id, ticket_no, title, created_at
FROM tickets
ORDER BY id
LIMIT 2 OFFSET 0;

SELECT id, ticket_no, title, created_at
FROM tickets
ORDER BY id
LIMIT 2 OFFSET 2;

-- 6. Aggregation for status boards.
SELECT status, COUNT(*) AS ticket_count
FROM tickets
GROUP BY status
ORDER BY ticket_count DESC;

SELECT priority, COUNT(*) AS ticket_count
FROM tickets
GROUP BY priority
ORDER BY ticket_count DESC;

-- 7. JOIN for common list pages.
SELECT
  t.id,
  t.ticket_no,
  c.name AS customer_name,
  a.name AS agent_name,
  t.title,
  t.priority,
  t.status
FROM tickets AS t
INNER JOIN customers AS c ON c.id = t.customer_id
LEFT JOIN agents AS a ON a.id = t.assigned_agent_id
ORDER BY t.created_at DESC;

-- Exercises:
-- A. Add one new customer and one ticket for that customer.
-- B. Query open high-priority tickets.
-- C. Query tickets assigned to Mina Support.
-- D. Count tickets by assigned agent.

SELECT 'Day 2 finished: INSERT and SELECT practice.' AS message;

