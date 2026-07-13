-- Day 6: verify restored data.
-- Use this after restoring into ops_demo or ops_demo_restore.

USE ops_demo;

SELECT 'ops_demo counts' AS section;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'agents', COUNT(*) FROM agents
UNION ALL
SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL
SELECT 'ticket_comments', COUNT(*) FROM ticket_comments
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs;

SELECT ticket_no, title, status, priority
FROM tickets
ORDER BY ticket_no;

-- If you restored into ops_demo_restore, run these manually:
-- USE ops_demo_restore;
-- SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
-- UNION ALL
-- SELECT 'agents', COUNT(*) FROM agents
-- UNION ALL
-- SELECT 'tickets', COUNT(*) FROM tickets
-- UNION ALL
-- SELECT 'ticket_comments', COUNT(*) FROM ticket_comments
-- UNION ALL
-- SELECT 'audit_logs', COUNT(*) FROM audit_logs;

SELECT 'Day 6 SQL check finished: compare row counts with Day 5.' AS message;

