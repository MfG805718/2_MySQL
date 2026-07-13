# Day 6 terminal commands: restore

这些命令在 macOS 终端里执行，不是在 MySQL 客户端里执行。

```bash
cd "/Users/liang_mac/Documents/MySQL study"
MYSQL_BIN="/Users/liang_mac/Documents/MySQL study/mysql-9.7.1-macos15-arm64/mysql-9.7.1-macos15-arm64/bin"
BACKUP_DIR="/Users/liang_mac/Documents/MySQL study/ops_demo_week2/backups"
```

如果你登录 MySQL 不是用 `/tmp/mysql.sock`，把下面的 `--socket=/tmp/mysql.sock` 换成你的连接参数。

## 1. Restore full backup into the original database

因为 `ops_demo_full.sql` 是用 `--databases ops_demo` 备份的，文件里包含库名：

```bash
"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock \
  < "$BACKUP_DIR/ops_demo_full.sql"
```

恢复后进入 MySQL 客户端执行：

```sql
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day06_restore_check.sql;
```

## 2. Restore into a new database for safer verification

很多项目里更推荐先恢复到新库，确认没问题再决定是否覆盖原库。

先创建新库：

```bash
"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock \
  -e "DROP DATABASE IF EXISTS ops_demo_restore; CREATE DATABASE ops_demo_restore CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;"
```

用 schema-only 和 data-only 恢复到新库：

```bash
"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock \
  ops_demo_restore < "$BACKUP_DIR/ops_demo_schema_only.sql"

"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock \
  ops_demo_restore < "$BACKUP_DIR/ops_demo_data_only.sql"
```

验证新库：

```bash
"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock ops_demo_restore \
  -e "SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers UNION ALL SELECT 'agents', COUNT(*) FROM agents UNION ALL SELECT 'tickets', COUNT(*) FROM tickets UNION ALL SELECT 'ticket_comments', COUNT(*) FROM ticket_comments UNION ALL SELECT 'audit_logs', COUNT(*) FROM audit_logs;"
```

## 3. Practice disaster recovery

只在练习库做：

```bash
"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock \
  -e "DROP DATABASE IF EXISTS ops_demo;"

"$MYSQL_BIN/mysql" -uroot --socket=/tmp/mysql.sock \
  < "$BACKUP_DIR/ops_demo_full.sql"
```

然后再次运行 Day 6 的 SQL 检查。

## 4. What to remember

- 恢复前确认你手里的备份文件是最新的。
- 优先恢复到新库做验证，不要一上来覆盖原库。
- 恢复后检查行数、关键业务记录、表结构和索引。
- 备份文件只是“看起来存在”不够，能成功恢复才算可靠。

