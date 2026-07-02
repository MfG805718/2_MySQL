# 2_MySQL

这是一个 MySQL 学习与实战练习仓库，目前核心内容是 `shop_demo_7day`：一套围绕电商订单、商品、库存、支付和日志场景设计的 7 天 SQL 练习项目。

项目目标是通过一个小型但完整的业务数据库，练习从建表、查询、JOIN、业务报表，到索引分析、事务一致性和项目交接排查的常见 MySQL 能力。

## 项目内容

```text
shop_demo_7day/
├── README.md
├── learning-notes-day03.md
├── learning-notes-day04.md
└── sql/
    ├── day01_schema_seed.sql
    ├── day02_basic_queries.sql
    ├── day03_joins_and_reports.sql
    ├── day04_subqueries_cte_window.sql
    ├── day05_indexes_explain.sql
    ├── day06_transactions_consistency.sql
    └── day07_project_handover.sql
```

## 练习主题

### Day 1：建库、建表与初始化数据

创建 `shop_demo` 数据库，并设计电商业务相关表：

- `users`：用户表
- `categories`：商品分类表
- `products`：商品表
- `inventory`：库存表
- `orders`：订单表
- `order_items`：订单明细表
- `payments`：支付表
- `operation_logs`：操作日志表

同时插入一批测试数据，用于后续查询和分析练习。

### Day 2：基础查询

练习 MySQL 常用查询能力，包括：

- `SELECT`
- `WHERE`
- `ORDER BY`
- `LIMIT`
- 聚合函数
- `GROUP BY`
- 基础统计查询

### Day 3：JOIN 与业务报表

围绕订单、用户、商品、分类等表，练习多表查询：

- `INNER JOIN`
- `LEFT JOIN`
- 订单详情查询
- 用户订单统计
- 商品销量统计
- 分类销售报表
- 查找“没有订单”或“没有关联数据”的记录

学习笔记中重点总结了 `LEFT JOIN` 中条件放在 `ON` 和 `WHERE` 的区别，以及 `COUNT(*)` 和 `COUNT(column)` 在外连接场景下的差异。

### Day 4：子查询、CTE 与窗口函数

从普通查询升级到业务分析型查询，练习：

- 子查询
- `IN`
- `EXISTS` / `NOT EXISTS`
- CTE
- 多个 CTE 拆解复杂业务问题
- 窗口函数
- 每组最新记录、每组排序、销售分析等场景

学习笔记中整理了如何把业务分析问题拆成 SQL 步骤。

### Day 5：索引与 EXPLAIN

练习 MySQL 查询优化的基础能力：

- 查看已有索引
- 使用 `EXPLAIN` 分析查询计划
- 创建普通索引和联合索引
- 理解联合索引的最左前缀原则
- 避免在索引列上包裹函数导致索引利用变差
- 针对订单列表、商品浏览、报表统计等高频查询设计索引

### Day 6：事务与数据一致性

练习订单和库存相关的事务场景：

- `START TRANSACTION`
- `COMMIT`
- `ROLLBACK`
- 创建订单时预占库存
- 支付订单时扣减库存并释放预占库存
- 使用 `SELECT ... FOR UPDATE` 锁定库存记录
- 利用唯一约束、外键约束、检查约束保证数据一致性

### Day 7：项目交接模拟

模拟接手一个已有 MySQL 项目时的排查流程：

- 查看表结构
- 查看索引
- 统计数据规模
- 检查库存异常
- 检查订单金额和明细金额是否一致
- 编写订单列表、订单详情、每日销售额、低库存预警等核心查询
- 判断哪些查询可能随着数据量增长变慢
- 判断哪些写操作必须放入事务

## 适合练习的能力

完成本项目后，应能初步掌握：

- 根据业务场景设计基础表结构
- 理解主键、外键、唯一约束、检查约束的作用
- 编写订单、商品、库存、支付相关的多表查询
- 使用聚合、分组、子查询、CTE 和窗口函数解决常见业务分析问题
- 使用 `EXPLAIN` 初步判断查询是否合理
- 为常见查询设计基础索引
- 理解订单创建、支付、库存扣减为什么需要事务
- 接手一个陌生数据库时，能快速查看结构、索引、数据规模和核心业务查询

## 运行方式

进入 MySQL 客户端后，按顺序执行 SQL 脚本：

```sql
source shop_demo_7day/sql/day01_schema_seed.sql;
source shop_demo_7day/sql/day02_basic_queries.sql;
source shop_demo_7day/sql/day03_joins_and_reports.sql;
source shop_demo_7day/sql/day04_subqueries_cte_window.sql;
source shop_demo_7day/sql/day05_indexes_explain.sql;
source shop_demo_7day/sql/day06_transactions_consistency.sql;
source shop_demo_7day/sql/day07_project_handover.sql;
```

注意：`day01_schema_seed.sql` 会执行：

```sql
DROP DATABASE IF EXISTS shop_demo;
```

它会重建练习数据库，适合从零开始练习，不要在重要数据库环境中直接运行。

## 仓库定位

这个仓库更偏向 MySQL 实战学习笔记和 SQL 练习集，不是一个完整后端应用。它适合用于复习 MySQL 基础、练习业务 SQL、理解电商订单库存模型，以及模拟接手数据库项目时的基本分析流程。
