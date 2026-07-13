-- Day 3: UPDATE and DELETE with safety habits.

USE ops_demo;

-- Rule: before UPDATE or DELETE, write a SELECT using the same WHERE.

-- 1. Safe UPDATE: first inspect.
SELECT id, name, phone
FROM customers
WHERE email = 'alice.chen@example.com';

UPDATE customers
SET phone = '13900002001'
WHERE email = 'alice.chen@example.com';

SELECT id, name, phone
FROM customers
WHERE email = 'alice.chen@example.com';

-- 2. Update ticket assignment and priority.
SELECT id, ticket_no, assigned_agent_id, priority, status
FROM tickets
WHERE ticket_no = 'TK202607040001';

UPDATE tickets
SET assigned_agent_id = 3,
    priority = 'low'
WHERE ticket_no = 'TK202607040001';

SELECT id, ticket_no, assigned_agent_id, priority, status
FROM tickets
WHERE ticket_no = 'TK202607040001';

-- 3. Transaction rollback demo for UPDATE.
START TRANSACTION;

UPDATE tickets
SET status = 'closed',
    closed_at = CURRENT_TIMESTAMP
WHERE status = 'open';

SELECT id, ticket_no, status, closed_at
FROM tickets
WHERE status = 'closed'
ORDER BY id;

ROLLBACK;

SELECT id, ticket_no, status, closed_at
FROM tickets
ORDER BY id;

-- 4. Soft delete pattern: mark inactive instead of deleting customer history.
SELECT id, name, status
FROM customers
WHERE email = 'dave.zhao@example.com';

UPDATE customers
SET status = 'inactive'
WHERE email = 'dave.zhao@example.com';

-- 5. DELETE child data safely.
-- Create a temporary comment, inspect it, then delete it.
INSERT INTO ticket_comments (ticket_id, author_type, author_name, body, is_internal)
VALUES (1, 'agent', 'Mina Support', 'Temporary duplicate comment for delete practice.', 1);

SELECT id, ticket_id, author_name, body
FROM ticket_comments
WHERE body = 'Temporary duplicate comment for delete practice.';

DELETE FROM ticket_comments
WHERE body = 'Temporary duplicate comment for delete practice.';

SELECT id, ticket_id, author_name, body
FROM ticket_comments
WHERE body = 'Temporary duplicate comment for delete practice.';

-- 6. DELETE parent row can fail when child rows exist.
-- Uncomment this to observe a foreign key error:
-- DELETE FROM tickets WHERE ticket_no = 'TK202607010001';

-- Exercises:
-- A. Change one open ticket to pending, then rollback.
-- B. Add and delete one audit log row.
-- C. Try deleting a customer with tickets and explain the foreign key error.

SELECT 'Day 3 finished: UPDATE, DELETE, rollback, and soft-delete habits.' AS message;

