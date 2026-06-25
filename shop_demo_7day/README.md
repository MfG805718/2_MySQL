# shop_demo 7-day MySQL practice

这是一套面向“1 周后能接手普通 MySQL 项目”的实战 SQL 教程。你已经能启动 MySQL，并且敲过基础语句，所以这里直接进入小型订单库存系统。

## How to run

先进入 MySQL 客户端：

```bash
cd "/Users/liang_mac/Documents/MySQL study/mysql-9.7.1-macos15-arm64/mysql-9.7.1-macos15-arm64"
bin/mysql -uroot --socket=/tmp/mysql.sock
```

然后按天执行：

```sql
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day01_schema_seed.sql;
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day02_basic_queries.sql;
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day03_joins_and_reports.sql;
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day04_subqueries_cte_window.sql;
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day05_indexes_explain.sql;
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day06_transactions_consistency.sql;
source /Users/liang_mac/Documents/MySQL study/shop_demo_7day/sql/day07_project_handover.sql;
```

注意：`day01_schema_seed.sql` 会 `DROP DATABASE IF EXISTS shop_demo`，用于从零重建练习库。

## Daily goals

- Day 1: 建库、建表、字段类型、主键、外键、基础测试数据。
- Day 2: `SELECT`、过滤、排序、分页、聚合、分组。
- Day 3: `INNER JOIN`、`LEFT JOIN`、订单详情和业务报表。
- Day 4: 子查询、CTE、窗口函数，解决“每组最新/最大”问题。
- Day 5: 索引、联合索引、`EXPLAIN`，初步判断慢查询。
- Day 6: 事务、回滚、库存扣减、唯一约束防重复。
- Day 7: 模拟接手项目：看表、看索引、检查数据、写交接查询。

## One-week handover checklist

学完后你应该能做到：

- 看到一个库，能用 `SHOW TABLES`、`SHOW CREATE TABLE`、`SHOW INDEX` 快速摸清结构。
- 能写订单列表、订单详情、统计报表、分页查询。
- 能给高频查询设计基础索引，并用 `EXPLAIN` 验证。
- 能理解创建订单、扣库存、写支付记录为什么必须放进事务。
- 能把重要 SQL 整理成可重复执行的脚本。

