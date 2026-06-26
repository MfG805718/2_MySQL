# Day 2 detailed plan: basic query ability

今天目标：把 `SELECT` 用熟。不是只会照抄语句，而是能把一个简单业务问题翻译成 SQL。

建议用时：2.5 到 4 小时。

## 0. 开始前检查

先进入 MySQL 客户端，并确认昨天的库还在：

```sql
USE shop_demo;
SHOW TABLES;
```

再快速看 4 张今天最常用的表：

```sql
DESC users;
DESC products;
DESC orders;
DESC inventory;
```

你要能说出：

- `users` 存用户。
- `products` 存商品。
- `orders` 存订单主记录。
- `inventory` 存每个商品的库存。

## 1. 读表和读列

先执行：

```sql
SELECT * FROM users;
SELECT id, username, email, status, created_at FROM users;
```

重点体会：

- `SELECT *` 适合学习和临时排查，不适合长期写在项目代码里。
- 项目查询应该明确列名，减少无用数据，也避免表结构变化时影响接口。

练习：

```sql
SELECT id, name, sku, price, status FROM products;
SELECT id, order_no, user_id, total_amount, status, created_at FROM orders;
```

验收：你能不用看答案，写出“查询商品列表”和“查询订单列表”的基础 SQL。

## 2. WHERE 条件过滤

先练等值查询：

```sql
SELECT id, username, status
FROM users
WHERE status = 'active';
```

再练范围查询：

```sql
SELECT id, name, price
FROM products
WHERE price BETWEEN 50 AND 150;
```

再练模式匹配：

```sql
SELECT id, name, sku
FROM products
WHERE sku LIKE 'ELEC%';
```

再练集合查询：

```sql
SELECT id, name, status
FROM products
WHERE status IN ('active', 'inactive');
```

你今天要特别注意：

- 字符串要用引号。
- `BETWEEN 50 AND 150` 包含 50 和 150。
- `LIKE 'ELEC%'` 表示以 `ELEC` 开头。
- `IN (...)` 适合多个离散值。

练习：

```sql
-- 找出 locked 用户。
SELECT id, username, status
FROM users
WHERE status = 'locked';

-- 找出价格小于 100 的 active 商品。
SELECT id, name, price
FROM products
WHERE status = 'active' AND price < 100;

-- 找出 sku 以 BOOK 开头的商品。
SELECT id, name, sku
FROM products
WHERE sku LIKE 'BOOK%';
```

验收：看到“筛选 active 商品且价格小于 100”，你能自然想到 `WHERE status = 'active' AND price < 100`。

## 3. ORDER BY 和 LIMIT

执行：

```sql
SELECT id, name, price
FROM products
WHERE status = 'active'
ORDER BY price DESC
LIMIT 3;
```

重点体会：

- `ORDER BY price DESC` 是从高到低。
- `ORDER BY price ASC` 是从低到高，`ASC` 可以省略。
- `LIMIT 3` 只取前 3 行。

练习：

```sql
-- 找最便宜的 3 个 active 商品。
SELECT id, name, price
FROM products
WHERE status = 'active'
ORDER BY price ASC
LIMIT 3;

-- 找最近创建的 5 个订单。
SELECT id, order_no, status, total_amount, created_at
FROM orders
ORDER BY created_at DESC
LIMIT 5;
```

验收：你能写“最新 N 条记录”和“最高/最低 N 个商品”。

## 4. 分页查询

执行：

```sql
SELECT id, name, price
FROM products
ORDER BY id
LIMIT 2 OFFSET 2;
```

理解分页公式：

```text
OFFSET = (page_number - 1) * page_size
```

例如：

- 第 1 页，每页 2 条：`LIMIT 2 OFFSET 0`
- 第 2 页，每页 2 条：`LIMIT 2 OFFSET 2`
- 第 3 页，每页 2 条：`LIMIT 2 OFFSET 4`

练习：

```sql
-- 商品列表第 1 页。
SELECT id, name, price
FROM products
ORDER BY id
LIMIT 2 OFFSET 0;

-- 商品列表第 3 页。
SELECT id, name, price
FROM products
ORDER BY id
LIMIT 2 OFFSET 4;
```

验收：别人给你 `page=3&pageSize=20`，你能算出 `LIMIT 20 OFFSET 40`。

## 5. 聚合函数

执行：

```sql
SELECT COUNT(*) AS user_count FROM users;
SELECT COUNT(*) AS active_product_count FROM products WHERE status = 'active';
SELECT MIN(price) AS min_price, MAX(price) AS max_price, AVG(price) AS avg_price FROM products;
```

重点体会：

- `COUNT(*)` 统计行数。
- `SUM(...)` 求和。
- `AVG(...)` 平均值。
- `MIN(...)` / `MAX(...)` 最小值、最大值。
- `AS` 是给结果列起别名，项目里很常用。

练习：

```sql
-- 订单总数。
SELECT COUNT(*) AS order_count FROM orders;

-- 已支付订单总金额。
SELECT SUM(total_amount) AS paid_amount
FROM orders
WHERE status = 'paid';

-- 商品平均价格。
SELECT AVG(price) AS avg_product_price
FROM products
WHERE status = 'active';
```

验收：你能写“统计数量”和“求总金额”。

## 6. GROUP BY 分组统计

执行：

```sql
SELECT status, COUNT(*) AS order_count, SUM(total_amount) AS total_amount
FROM orders
GROUP BY status;
```

这句的业务含义是：按订单状态统计订单数量和金额。

再执行：

```sql
SELECT DATE(created_at) AS order_date, COUNT(*) AS order_count, SUM(total_amount) AS total_amount
FROM orders
GROUP BY DATE(created_at)
ORDER BY order_date;
```

这句的业务含义是：按天统计订单数量和金额。

练习：

```sql
-- 按用户统计订单数量和订单总金额。
SELECT user_id, COUNT(*) AS order_count, SUM(total_amount) AS total_amount
FROM orders
GROUP BY user_id;

-- 按商品状态统计商品数量。
SELECT status, COUNT(*) AS product_count
FROM products
GROUP BY status;
```

验收：看到“每个/每类/每天/每种状态”，你能想到 `GROUP BY`。

## 7. HAVING 过滤分组结果

执行：

```sql
SELECT user_id, COUNT(*) AS order_count, SUM(total_amount) AS total_spent
FROM orders
GROUP BY user_id
HAVING SUM(total_amount) >= 150;
```

重点区分：

- `WHERE` 过滤原始行。
- `HAVING` 过滤分组后的结果。

练习：

```sql
-- 找出订单数大于等于 2 的用户。
SELECT user_id, COUNT(*) AS order_count
FROM orders
GROUP BY user_id
HAVING COUNT(*) >= 2;

-- 找出总销售额大于 100 的订单状态。
SELECT status, SUM(total_amount) AS total_amount
FROM orders
GROUP BY status
HAVING SUM(total_amount) > 100;
```

验收：你能解释为什么聚合条件不能直接写在 `WHERE SUM(...)` 里。

## 8. 今天最后的项目化练习

不要看前面的答案，独立写出这些 SQL：

1. 查询所有 active 用户，只显示 `id`、`username`、`email`。
2. 查询价格在 50 到 200 之间的 active 商品，按价格从低到高排序。
3. 查询最近创建的 3 个订单。
4. 查询每种订单状态下有多少订单、总金额是多少。
5. 查询每个用户的订单数和订单总金额。
6. 查询订单总金额超过 150 的用户。
7. 查询 2026-06-20 到 2026-06-23 之间创建的订单数。
8. 查询 active 商品的最低价、最高价、平均价。

## 9. 复盘问题

今天结束前，口头回答这些问题：

- `WHERE` 和 `HAVING` 有什么区别？
- `ORDER BY created_at DESC LIMIT 5` 常用在什么业务场景？
- `LIMIT 20 OFFSET 40` 表示第几页？
- `COUNT(*)` 和 `SUM(total_amount)` 分别解决什么问题？
- 为什么项目代码里不建议长期使用 `SELECT *`？

## 10. 执行原脚本

完成上面的分步练习后，再执行原始 Day 2 脚本做一次完整串联：

```sql
source /Users/liang_mac/.codex/worktrees/a0ae/MySQL study/shop_demo_7day/sql/day02_basic_queries.sql;
```

