-- Day 5: SQL checks before and after backups.
-- Run this before terminal/day05_backup_commands.md to record expected counts.

USE ops_demo;

SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'agents', COUNT(*) FROM agents
UNION ALL
SELECT 'tickets', COUNT(*) FROM tickets
UNION ALL
SELECT 'ticket_comments', COUNT(*) FROM ticket_comments
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs;

SELECT id, ticket_no, title, status
FROM tickets
ORDER BY id;

SHOW CREATE TABLE tickets;

SELECT 'Day 5 SQL check finished: now run terminal/day05_backup_commands.md in macOS Terminal.' AS message;

