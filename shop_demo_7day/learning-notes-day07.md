# Day 7 Notes: Project Handover Simulation

今天的主题不是学习更多零散语法，而是模拟真实接手一个 MySQL 项目。前 6 天已经练过建表、查询、JOIN、CTE、窗口函数、索引和事务；Day 7 要把这些能力串起来，形成一套固定的项目接手方法。

核心目标：

```text
先看结构，再看数据规模，再做健康检查，再看核心业务 SQL，最后判断索引和事务风险。
```

## 1. 接手项目时先看什么

拿到一个数据库后，不要一上来就改 SQL 或改数据。第一步应该先摸清楚：

```text
有哪些表？
每张表负责什么业务？
表和表之间怎么关联？
哪些字段是主键、外键、唯一键？
哪些索引用来支持高频查询？
```

常用命令：

```sql
SHOW TABLES;
SHOW CREATE TABLE orders;
SHOW CREATE TABLE order_items;
SHOW INDEX FROM orders;
SHOW INDEX FROM products;
```

`SHOW TABLES` 用来快速看数据库里有哪些表。

`SHOW CREATE TABLE` 比 `DESC` 更完整，因为它能看到：

```text
字段类型
主键
唯一键
普通索引
外键
CHECK 约束
存储引擎
字符集
```

`SHOW INDEX` 用来查看索引，重点看：

```text
Key_name：索引名。
Seq_in_index：字段在联合索引里的顺序。
Column_name：索引字段。
Non_unique：是否允许重复。
```

## 2. 当前 shop_demo 的核心业务关系

当前项目可以理解成一个小型订单库存系统。

表关系：

```text
users 1 --- N orders
orders 1 --- N order_items
products 1 --- N order_items
categories 1 --- N products
products 1 --- 1 inventory
orders 1 --- 0/1 payments
```

更具体地说：

```text
users：用户。
categories：商品分类。
products：商品。
inventory：库存。
orders：订单主表。
order_items：订单明细。
payments：支付记录。
operation_logs：操作日志。
```

订单详情的核心查询路径是：

```text
orders -> order_items -> products
```

注意：`orders` 和 `products` 不是直接关联的，中间必须经过 `order_items`。

## 3. 重要约束和唯一键

接手项目时要重点看唯一键，因为它们通常是在数据库层面防止重复数据的最后防线。

当前项目里比较重要的唯一约束：

```text
users.username：防止用户名重复。
users.email：防止邮箱重复。
categories.name：防止分类名重复。
products.sku：防止商品 SKU 重复。
orders.order_no：防止订单号重复。
payments.payment_no：防止支付流水号重复。
payments(order_id, status)：限制同一订单同一支付状态的重复记录。
```

理解这些约束很重要。项目里很多“重复提交”“重复支付”“重复创建”的问题，不能只依赖应用代码判断，数据库也应该有约束兜底。

## 4. 数据规模统计

Day 7 里用了这段 SQL：

```sql
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'operation_logs', COUNT(*) FROM operation_logs;
```

### 4.1 UNION ALL 的作用

`UNION ALL` 的作用是把多条 `SELECT` 的结果纵向拼接成一张结果表。

如果分别执行：

```sql
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM products;
SELECT COUNT(*) FROM orders;
```

会得到多个分散的结果。

使用 `UNION ALL` 后，可以得到一张统一的体检表：

```text
table_name      row_count
users           5
products        7
inventory       7
orders          7
order_items     9
payments        5
operation_logs  5
```

`UNION` 和 `UNION ALL` 的区别：

```text
UNION：合并结果并去重。
UNION ALL：直接合并结果，不去重。
```

这里每一行的 `table_name` 都不同，本来就不需要去重，所以使用 `UNION ALL` 更合适。

### 4.2 数据规模统计能看出什么

数据规模统计不能直接证明业务数据完全正确，但它可以帮助快速建立项目直觉。

重点看这些比例：

```text
order_items 通常应该 >= orders。
payments 通常应该 <= orders，除非允许多次支付、失败支付、退款记录。
inventory 通常应该接近 products。
operation_logs 可能会随着业务操作快速增长。
```

如果看到：

```text
products  100
inventory 80
```

就要怀疑是否有商品没有库存记录。

如果看到：

```text
orders      10000
order_items 20
```

就要怀疑订单明细是否缺失，或者统计口径不对。

如果看到：

```text
orders   10000
payments 30000
```

不一定错，但必须追问：

```text
一个订单是否允许多次支付？
失败支付是否也记录在 payments？
退款是否也记录在 payments？
是否存在重复支付？
```

一句话总结：

```text
COUNT(*) 是项目接手时最便宜的第一轮体检。
它不解决问题，但能告诉我应该优先检查哪里。
```

## 5. 数据健康检查

数据规模统计之后，要继续做更具体的健康检查。

### 5.1 检查商品是否都有库存记录

```sql
SELECT p.id, p.name
FROM products AS p
LEFT JOIN inventory AS i ON i.product_id = p.id
WHERE i.product_id IS NULL;
```

这个查询使用了 Day 3 学过的“找没有”的模式：

```text
LEFT JOIN 右表
WHERE 右表主键 IS NULL
```

含义：

```text
先保留所有 products。
尝试关联 inventory。
关联不上的商品，inventory 字段就是 NULL。
```

### 5.2 检查库存预占是否超过真实库存

```sql
SELECT i.product_id, p.name, i.stock, i.reserved_stock
FROM inventory AS i
INNER JOIN products AS p ON p.id = i.product_id
WHERE i.reserved_stock > i.stock;
```

如果 `reserved_stock > stock`，说明系统进入了不合理状态。

正常情况下应该满足：

```text
stock >= 0
reserved_stock >= 0
reserved_stock <= stock
available_stock = stock - reserved_stock
```

### 5.3 检查订单总金额和明细金额是否一致

```sql
SELECT
  o.id,
  o.order_no,
  o.status,
  o.total_amount,
  COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS item_amount
FROM orders AS o
LEFT JOIN order_items AS oi ON oi.order_id = o.id
GROUP BY o.id, o.order_no, o.status, o.total_amount
HAVING ABS(o.total_amount - item_amount) > 0.001;
```

这条 SQL 的目的：

```text
orders.total_amount 应该等于 order_items 的金额汇总。
```

这里使用 `LEFT JOIN` 是为了连没有明细的订单也能检查出来。

`COALESCE(..., 0)` 的作用是：

```text
如果 SUM 结果是 NULL，就当作 0。
```

`HAVING` 的作用是筛选聚合后的结果。因为 `item_amount` 是聚合后算出来的，不能在 `WHERE` 里过滤。

## 6. 核心业务查询

接手项目时，核心业务查询比孤立语法更重要。要训练自己从业务需求反推 SQL 路径。

### 6.1 订单列表页

```sql
SELECT
  o.id,
  o.order_no,
  u.username,
  o.status,
  o.total_amount,
  o.created_at
FROM orders AS o
INNER JOIN users AS u ON u.id = o.user_id
ORDER BY o.created_at DESC
LIMIT 20;
```

业务理解：

```text
主表是 orders。
需要展示用户名，所以 JOIN users。
列表页通常需要按时间倒序。
真实项目通常还会加 status、user_id、时间范围等筛选条件。
```

### 6.2 订单详情页

```sql
SELECT
  o.order_no,
  o.status,
  u.username,
  p.name AS product_name,
  oi.quantity,
  oi.unit_price,
  oi.quantity * oi.unit_price AS line_amount
FROM orders AS o
INNER JOIN users AS u ON u.id = o.user_id
INNER JOIN order_items AS oi ON oi.order_id = o.id
INNER JOIN products AS p ON p.id = oi.product_id
WHERE o.order_no = 'OD202606240001';
```

查询路径：

```text
orders -> users
orders -> order_items -> products
```

这个查询是项目里非常典型的详情页 SQL。

### 6.3 每日已支付销售额

```sql
SELECT
  DATE(paid_at) AS sales_date,
  COUNT(*) AS paid_order_count,
  SUM(total_amount) AS paid_amount
FROM orders
WHERE status = 'paid'
GROUP BY DATE(paid_at)
ORDER BY sales_date;
```

业务粒度：

```text
每一天一行。
只统计 paid 订单。
统计订单数量和销售额。
```

注意：`GROUP BY DATE(paid_at)` 是按日期统计。真实大表里，如果要按日期范围过滤，尽量写成：

```sql
WHERE paid_at >= '2026-06-01'
  AND paid_at < '2026-07-01'
```

不要写成：

```sql
WHERE DATE(paid_at) = '2026-06-01'
```

因为在索引列上套函数，可能让索引不容易被高效使用。

### 6.4 低库存预警

```sql
SELECT
  p.id,
  p.name,
  i.stock,
  i.reserved_stock,
  i.stock - i.reserved_stock AS available_stock
FROM inventory AS i
INNER JOIN products AS p ON p.id = i.product_id
WHERE i.stock - i.reserved_stock < 10
ORDER BY available_stock, p.id;
```

库存判断不能只看 `stock`，还要看：

```text
available_stock = stock - reserved_stock
```

如果真实库存是 100，但已经预占 95，那么可售库存只有 5。

### 6.5 每个用户最近一笔订单

```sql
WITH ranked_orders AS (
  SELECT
    o.*,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC, id DESC) AS rn
  FROM orders AS o
)
SELECT u.username, ro.order_no, ro.status, ro.total_amount, ro.created_at
FROM ranked_orders AS ro
INNER JOIN users AS u ON u.id = ro.user_id
WHERE ro.rn = 1
ORDER BY ro.created_at DESC;
```

这是 Day 4 的重点：“每组最新一条”。

理解方式：

```text
PARTITION BY user_id：每个用户分成一组。
ORDER BY created_at DESC, id DESC：每组内部按时间倒序。
ROW_NUMBER()：给每组内部编号。
rn = 1：取每个用户最新的一条。
```

以后看到类似需求：

```text
每个用户最近一笔订单。
每个商品最新一次库存变动。
每个订单最新一次支付记录。
每个设备最新一条日志。
```

都可以优先想到窗口函数。

## 7. EXPLAIN 什么时候用

接手项目后，不是每条 SQL 都必须 `EXPLAIN`。主要在这些情况下使用：

```text
页面慢、接口超时。
写了新的核心查询，准备上线。
准备加索引或调整索引。
SQL 涉及大表 JOIN、GROUP BY、ORDER BY、LIMIT。
现在数据不大，但未来会快速增长。
```

一句话：

```text
慢的、重要的、会变大的、准备上线的、准备加索引的 SQL，都应该 EXPLAIN。
```

## 8. EXPLAIN 重点看什么

如果 MySQL 显示传统表格，先重点看：

```text
table：当前访问哪张表。
type：访问方式。const / ref / range 通常比 ALL 好。
key：实际使用了哪个索引。
rows：预估扫描多少行。
Extra：是否有 Using filesort / Using temporary。
```

快速判断：

```text
key 为空：可能没有用到索引。
type 是 ALL：可能在全表扫描。
rows 很大：扫描范围可能太大。
Using filesort：ORDER BY 可能没有很好利用索引。
Using temporary：GROUP BY / DISTINCT 可能成本较高。
```

但也不能机械判断。小表全表扫描不一定有问题，比如 `categories` 只有几十行时，`type = ALL` 通常没必要紧张。

## 9. Day 7 里的两个 EXPLAIN

### 9.1 用户已支付订单列表

```sql
EXPLAIN
SELECT id, order_no, total_amount, created_at
FROM orders
WHERE user_id = 1 AND status = 'paid'
ORDER BY created_at DESC
LIMIT 10;
```

理想索引：

```text
idx_orders_user_status_created(user_id, status, created_at)
```

原因：

```text
WHERE user_id = ?
AND status = ?
ORDER BY created_at DESC
```

刚好符合联合索引的字段顺序：

```text
user_id -> status -> created_at
```

这就是 Day 5 里的最左前缀原则。

### 9.2 商品浏览查询

```sql
EXPLAIN
SELECT id, name, price
FROM products
WHERE status = 'active' AND price BETWEEN 50 AND 200
ORDER BY price, id
LIMIT 10;
```

理想索引：

```text
idx_products_status_price_id(status, price, id)
```

原因：

```text
先用 status 过滤。
再用 price 做范围筛选。
最后按 price, id 排序和分页。
```

这个查询很像真实项目里的商品列表页。

## 10. 事务边界复盘

Day 6 学过事务后，Day 7 要从项目接手角度判断：哪些写操作必须放进事务。

原则：

```text
只要一个业务动作会同时修改多张表，就优先考虑事务。
只要不能接受半成功，就必须考虑事务。
```

当前项目里应该放进事务的操作：

```text
创建订单：
预占库存 + 创建 orders + 创建 order_items + 写 operation_logs。

支付订单：
修改 orders.status + 写 payments + 扣 stock + 释放 reserved_stock + 写 operation_logs。

取消订单：
修改 orders.status + 释放 reserved_stock + 写 operation_logs。

退款：
修改支付状态 + 修改订单状态 + 写退款记录或日志。
```

如果不使用事务，可能出现：

```text
订单创建了，但订单明细没创建。
支付成功了，但订单状态还是 created。
库存扣了，但支付记录没写。
订单取消了，但 reserved_stock 没释放。
```

这些都是项目里很严重的数据一致性问题。

## 11. SELECT ... FOR UPDATE 的意义

库存相关操作要特别小心并发。

典型场景：

```text
多个用户同时购买同一个商品。
```

如果只是先查库存，再更新库存，中间可能被其他事务插入操作。

`SELECT ... FOR UPDATE` 的意义是：

```text
在事务中读取并锁定将要修改的行，避免其他事务同时修改同一行。
```

例如：

```sql
START TRANSACTION;

SELECT product_id, stock, reserved_stock
FROM inventory
WHERE product_id = 1
FOR UPDATE;

UPDATE inventory
SET reserved_stock = reserved_stock + 1
WHERE product_id = 1
  AND stock - reserved_stock >= 1;

COMMIT;
```

也可以使用条件 `UPDATE` 来避免超卖：

```sql
UPDATE inventory
SET reserved_stock = reserved_stock + 1
WHERE product_id = 1
  AND stock - reserved_stock >= 1;
```

执行后要检查影响行数。如果影响行数是 0，说明库存不足或记录不存在。

## 12. 最终交接问题答案

### A. Which table owns order status?

`orders` 表拥有订单状态，字段是：

```text
orders.status
```

支付表 `payments.status` 只表示支付记录本身的状态，不等于订单整体状态。

### B. Which unique keys prevent duplicate users, duplicate orders, and duplicate payments?

防重复用户：

```text
uk_users_username(username)
uk_users_email(email)
```

防重复商品业务编号：

```text
uk_products_sku(sku)
```

防重复订单：

```text
uk_orders_order_no(order_no)
```

防重复支付流水：

```text
uk_payments_payment_no(payment_no)
```

限制同一订单同一支付状态重复：

```text
uk_payments_order_success(order_id, status)
```

### C. Which query would slow down first if orders grew from 10 rows to 10 million rows?

最容易先慢的是围绕大表的查询：

```text
订单列表页。
用户订单历史。
订单明细 JOIN。
每日销售额统计。
商品销量统计。
操作日志查询。
```

重点关注的表：

```text
orders
order_items
payments
operation_logs
```

这些表会随着业务增长快速变大。

### D. Which writes must be wrapped in a transaction?

必须重点考虑事务的写操作：

```text
创建订单。
支付订单。
取消订单。
退款。
扣库存。
释放库存。
写支付记录。
写关键业务日志。
```

判断标准：

```text
一个业务动作中，只要多张表必须一起成功或一起失败，就应该使用事务。
```

### E. Which indexes support the order list page and product browsing page?

订单列表相关索引：

```text
idx_orders_user_created(user_id, created_at)
idx_orders_status_created(status, created_at)
idx_orders_user_status_created(user_id, status, created_at)
uk_orders_order_no(order_no)
```

商品浏览相关索引：

```text
idx_products_category(category_id)
idx_products_status_price_id(status, price, id)
uk_products_sku(sku)
```

## 13. 今天真正掌握的能力

完成 Day 7 后，应该具备下面这些项目接手能力：

```text
能用 SHOW TABLES / SHOW CREATE TABLE / SHOW INDEX 快速摸清结构。
能画出核心表之间的关系。
能通过 COUNT(*) + UNION ALL 快速看数据规模。
能用 LEFT JOIN ... IS NULL 找缺失关联数据。
能检查订单金额、库存预占这类基础数据健康问题。
能写订单列表、订单详情、日报、库存预警、每组最新一条。
能对高频查询使用 EXPLAIN。
能解释常见索引为什么适合某条查询。
能判断哪些写操作必须使用事务。
```

Day 7 的核心不是“我又学了一个 SQL 语法”，而是：

```text
我开始能像项目维护者一样看数据库。
```

