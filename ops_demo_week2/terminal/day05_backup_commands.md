# Day 5 terminal commands: backup

这些命令在 macOS 终端里执行，不是在 MySQL 客户端里执行。

先准备变量。因为路径里有空格，命令里都用了引号。

```bash
cd "/Users/liang_mac/Documents/MySQL study"
mkdir -p ops_demo_week2/backups
MYSQL_BIN="/Users/liang_mac/Documents/MySQL study/mysql-9.7.1-macos15-arm64/mysql-9.7.1-macos15-arm64/bin"
BACKUP_DIR="/Users/liang_mac/Documents/MySQL study/ops_demo_week2/backups"
```

如果你登录 MySQL 不是用 `/tmp/mysql.sock`，把下面的 `--socket=/tmp/mysql.sock` 换成你的连接参数，例如 `-h127.0.0.1 -P3306`。

## 1. Full database backup

```bash
"$MYSQL_BIN/mysqldump" -uroot --socket=/tmp/mysql.sock \
  --databases ops_demo \
  --routines --events --triggers \
  > "$BACKUP_DIR/ops_demo_full.sql"
```

检查文件：

```bash
ls -lh "$BACKUP_DIR"
head -n 30 "$BACKUP_DIR/ops_demo_full.sql"
```

## 2. Schema-only backup

```bash
"$MYSQL_BIN/mysqldump" -uroot --socket=/tmp/mysql.sock \
  --no-data ops_demo \
  > "$BACKUP_DIR/ops_demo_schema_only.sql"
```

## 3. Data-only backup

```bash
"$MYSQL_BIN/mysqldump" -uroot --socket=/tmp/mysql.sock \
  --no-create-info ops_demo \
  > "$BACKUP_DIR/ops_demo_data_only.sql"
```

## 4. Single-table backup

```bash
"$MYSQL_BIN/mysqldump" -uroot --socket=/tmp/mysql.sock \
  ops_demo tickets \
  > "$BACKUP_DIR/ops_demo_tickets_only.sql"
```

## 5. What to remember

- `--databases ops_demo` 会在备份文件里包含 `CREATE DATABASE` 和 `USE`。
- `--no-data` 只备份表结构。
- `--no-create-info` 只备份数据。
- 单表备份适合导出某一张业务表，但恢复时要注意外键依赖。
- 真项目备份后要验证文件大小、关键表行数、能否恢复到新库。

