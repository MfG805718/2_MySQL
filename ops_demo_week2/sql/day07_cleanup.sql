-- Day 7: cleanup practice.
-- WARNING: This file intentionally deletes data in ops_demo only.

USE ops_demo;

-- 1. Always inspect counts before cleanup.
SELECT 'before cleanup' AS section;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'agents', COUNT(*) FROM agents
UNION ALL
SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL
SELECT 'ticket_comments', COUNT(*) FROM ticket_comments
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs;

-- 2. Transaction rollback demo: prove that DELETE can be rolled back.
START TRANSACTION;

DELETE FROM audit_logs;
DELETE FROM ticket_comments;

SELECT 'inside transaction after delete' AS section;
SELECT COUNT(*) AS audit_log_count FROM audit_logs;
SELECT COUNT(*) AS comment_count FROM ticket_comments;

ROLLBACK;

SELECT 'after rollback' AS section;
SELECT COUNT(*) AS audit_log_count FROM audit_logs;
SELECT COUNT(*) AS comment_count FROM ticket_comments;

-- 3. Clean child tables first, then parent tables.
-- This order respects foreign keys:
-- ticket_comments -> audit_logs -> tickets -> customers/agents

START TRANSACTION;

DELETE FROM ticket_comments;
DELETE FROM audit_logs;
DELETE FROM tickets;
DELETE FROM customers;
DELETE FROM agents;

SELECT 'inside transaction after full cleanup' AS section;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'agents', COUNT(*) FROM agents
UNION ALL
SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL
SELECT 'ticket_comments', COUNT(*) FROM ticket_comments
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs;

-- Change ROLLBACK to COMMIT only after you are comfortable.
ROLLBACK;

-- 4. TRUNCATE is faster but more dangerous.
-- In MySQL, TRUNCATE causes an implicit commit and cannot be rolled back like DELETE.
-- Uncomment only in a disposable practice database:
-- SET FOREIGN_KEY_CHECKS = 0;
-- TRUNCATE TABLE ticket_comments;
-- TRUNCATE TABLE audit_logs;
-- TRUNCATE TABLE tickets;
-- TRUNCATE TABLE customers;
-- TRUNCATE TABLE agents;
-- SET FOREIGN_KEY_CHECKS = 1;

-- 5. Final safe reset option: re-run day01_schema_seed.sql.
-- source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day01_schema_seed.sql;

SELECT 'Day 7 finished: cleanup patterns practiced safely with rollback.' AS message;

