-- Day 4: practical CRUD flows from a project point of view.

USE ops_demo;

-- Flow 1: Create a customer and a ticket in one transaction.
START TRANSACTION;

INSERT INTO customers (name, email, phone, company)
VALUES ('Frank Yu', 'frank.yu@example.com', '13800001006', 'Cloud Bridge');

SET @customer_id = LAST_INSERT_ID();

INSERT INTO tickets (ticket_no, customer_id, assigned_agent_id, title, priority, status)
VALUES ('TK202607060001', @customer_id, 1, 'Cannot receive email notifications', 'high', 'open');

SET @ticket_id = LAST_INSERT_ID();

INSERT INTO ticket_comments (ticket_id, author_type, author_name, body, is_internal)
VALUES (@ticket_id, 'customer', 'Frank Yu', 'No one in our company receives notifications.', 0);

INSERT INTO audit_logs (actor, action, target_table, target_id, detail)
VALUES ('system', 'create_ticket', 'tickets', @ticket_id, 'created by day 4 transaction flow');

COMMIT;

SELECT
  t.ticket_no,
  c.name AS customer_name,
  t.title,
  t.priority,
  t.status
FROM tickets AS t
INNER JOIN customers AS c ON c.id = t.customer_id
WHERE t.ticket_no = 'TK202607060001';

-- Flow 2: Read a ticket detail page.
SELECT
  t.ticket_no,
  t.title,
  t.priority,
  t.status,
  c.name AS customer_name,
  c.email AS customer_email,
  a.name AS agent_name
FROM tickets AS t
INNER JOIN customers AS c ON c.id = t.customer_id
LEFT JOIN agents AS a ON a.id = t.assigned_agent_id
WHERE t.ticket_no = 'TK202607060001';

SELECT author_type, author_name, body, is_internal, created_at
FROM ticket_comments
WHERE ticket_id = (
  SELECT id FROM tickets WHERE ticket_no = 'TK202607060001'
)
ORDER BY created_at;

-- Flow 3: Update status and add an audit log.
START TRANSACTION;

SELECT id, ticket_no, status
FROM tickets
WHERE ticket_no = 'TK202607060001'
FOR UPDATE;

UPDATE tickets
SET status = 'pending'
WHERE ticket_no = 'TK202607060001' AND status = 'open';

INSERT INTO audit_logs (actor, action, target_table, target_id, detail)
SELECT 'mina.support', 'update_status', 'tickets', id, 'open -> pending'
FROM tickets
WHERE ticket_no = 'TK202607060001';

COMMIT;

-- Flow 4: Close a ticket.
START TRANSACTION;

UPDATE tickets
SET status = 'closed',
    closed_at = CURRENT_TIMESTAMP
WHERE ticket_no = 'TK202607060001' AND status IN ('open', 'pending');

INSERT INTO ticket_comments (ticket_id, author_type, author_name, body, is_internal)
SELECT id, 'agent', 'Mina Support', 'Notifications were fixed and verified.', 0
FROM tickets
WHERE ticket_no = 'TK202607060001';

INSERT INTO audit_logs (actor, action, target_table, target_id, detail)
SELECT 'mina.support', 'close_ticket', 'tickets', id, 'ticket resolved'
FROM tickets
WHERE ticket_no = 'TK202607060001';

COMMIT;

SELECT ticket_no, status, closed_at
FROM tickets
WHERE ticket_no = 'TK202607060001';

-- Flow 5: Delete a mistaken comment, not the whole ticket.
INSERT INTO ticket_comments (ticket_id, author_type, author_name, body, is_internal)
SELECT id, 'agent', 'Mina Support', 'Wrong comment for delete practice.', 1
FROM tickets
WHERE ticket_no = 'TK202607060001';

SELECT id, body
FROM ticket_comments
WHERE body = 'Wrong comment for delete practice.';

DELETE FROM ticket_comments
WHERE body = 'Wrong comment for delete practice.';

-- Exercises:
-- A. Create another customer + ticket in one transaction.
-- B. Assign that ticket to Nora QA.
-- C. Add one public comment and one internal comment.
-- D. Close the ticket and verify it appears in the closed ticket list.

SELECT 'Day 4 finished: full project CRUD flows.' AS message;

