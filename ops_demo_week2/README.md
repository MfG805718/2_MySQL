# ops_demo week 2: CRUD, backup, restore, and cleanup

这是一套新的 7 天练习，目标非常贴近项目上最常见的数据库工作：

- 增：`INSERT`
- 查：`SELECT`
- 改：`UPDATE`
- 删：`DELETE`
- 备份：`mysqldump`
- 还原：`mysql < backup.sql`
- 清库：安全清理数据、重建练习库

练习库名是 `ops_demo`，和第一周的 `shop_demo` 分开。

## How to run SQL files

进入 MySQL 客户端后按天执行：

```sql
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day01_schema_seed.sql;
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day02_insert_select.sql;
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day03_update_delete.sql;
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day04_project_crud_flows.sql;
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day05_backup_check.sql;
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day06_restore_check.sql;
source /Users/liang_mac/Documents/MySQL study/ops_demo_week2/sql/day07_cleanup.sql;
```

`day01_schema_seed.sql` 会重建 `ops_demo`，只适合练习环境。

Day 2 到 Day 4 会插入新的练习数据。如果你想从头再练一遍，先重新执行 Day 1，避免重复邮箱、重复工单号触发唯一键错误。

## Terminal command days

备份和还原不是纯 SQL 操作，需要在 macOS 终端执行：

- Day 5: `terminal/day05_backup_commands.md`
- Day 6: `terminal/day06_restore_commands.md`

里面的命令默认使用你当前目录下的 MySQL 二进制：

```text
/Users/liang_mac/Documents/MySQL study/mysql-9.7.1-macos15-arm64/mysql-9.7.1-macos15-arm64/bin
```

如果你的 socket 不是 `/tmp/mysql.sock`，把命令里的 `--socket=/tmp/mysql.sock` 换成你实际登录 MySQL 时使用的连接方式。

## Daily goals

- Day 1: 建一个项目上很常见的工单/客户练习库。
- Day 2: 练 `INSERT` 和 `SELECT`，掌握基础查询、过滤、分页、模糊搜索。
- Day 3: 练 `UPDATE` 和 `DELETE`，重点是先查后改、事务回滚、软删除。
- Day 4: 串起真实 CRUD 流程：新增客户、创建工单、追加评论、改状态、撤销误操作。
- Day 5: 备份：全库备份、只备份结构、只备份数据、单表备份。
- Day 6: 还原：恢复原库、恢复到新库、验证行数和关键数据。
- Day 7: 清库：按依赖顺序 `DELETE`，使用 `TRUNCATE`，重建库，理解危险边界。

## Safety rules

1. 任何 `UPDATE` / `DELETE` 之前，先写同条件的 `SELECT`。
2. 练习阶段默认用事务包住危险操作：`START TRANSACTION`，确认后 `COMMIT`，不对就 `ROLLBACK`。
3. 线上环境不要随手用 `DROP DATABASE`、`TRUNCATE`、`DELETE FROM table`。
4. 清库前先备份，清库后做行数检查。
5. 不确定就先恢复到一个新库，例如 `ops_demo_restore`，不要直接覆盖原库。
