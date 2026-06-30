# Day 3 learning notes: JOIN, aggregation, and SQL execution order

这份记录总结第 3 天练习中已经遇到的重点和卡点。今天的难点不是单个语法，而是把业务需求翻译成多表查询：先确定主体表，再确定 JOIN 路径，再决定过滤条件放在 `ON`、`WHERE` 还是 `HAVING`。

## 今天已经掌握的内容

### 1. 能根据表关系写 JOIN

当前项目里的核心关系：

```text
users 1 --- N orders
orders 1 --- N order_items
products 1 --- N order_items
categories 1 --- N products
products 1 --- 1 inventory
orders 1 --- 0/1 payments
```

典型订单详情路径：

```text
orders -> order_items -> products
```

对应 SQL：

```sql
SELECT
  o.order_no,
  p.name,
  oi.quantity,
  oi.unit_price,
  oi.quantity * oi.unit_price AS line_amount
FROM orders AS o
INNER JOIN order_items AS oi ON oi.order_id = o.id
INNER JOIN products AS p ON p.id = oi.product_id
WHERE o.order_no = 'OD202606200001';
```

要点：订单和商品不是直接关联的，中间必须经过 `order_items`。

### 2. 初步理解 INNER JOIN 和 LEFT JOIN

`INNER JOIN`：

```text
左右两边都匹配成功，结果才保留。
```

适合：

```text
只看已经有关联的数据
只看已存在订单的用户
只看有订单明细的商品
```

`LEFT JOIN`：

```text
左表一定保留；右表匹配不上时，右表字段为 NULL。
```

适合：

```text
所有用户 + 订单数
所有商品 + 销量
所有分类 + 销售额
找没有订单的用户
找没有库存记录的商品
```

一句话记忆：

```text
INNER JOIN：匹配不上就不要。
LEFT JOIN：左边一定要，右边没有就填 NULL。
```

## 今天不太熟练、需要重点复习的地方

### 1. LEFT JOIN 中右表条件放 ON 还是 WHERE

这是今天最重要的卡点。

如果需求是：

```text
所有用户 + 已支付订单数
所有商品 + 已支付销量
所有分类 + 已支付销售额
```

关键词是：

```text
所有 X + 满足某条件的统计
```

这种情况通常要保留左表全部记录，所以右表过滤条件应该放在 `ON` 里：

```sql
LEFT JOIN orders AS o
  ON o.id = oi.order_id
 AND o.status = 'paid'
```

如果写成：

```sql
WHERE o.status = 'paid'
```

没有 paid 订单的左表记录会被过滤掉，`LEFT JOIN` 会变得像 `INNER JOIN`。

判断口诀：

```text
要保留左表全部，右表条件放 ON。
要筛掉整行结果，条件放 WHERE。
```

### 2. 找“没有”的模式

找没有匹配记录时，常用：

```sql
SELECT
  u.id,
  u.username
FROM users AS u
LEFT JOIN orders AS o ON o.user_id = u.id
WHERE o.id IS NULL;
```

含义：

```text
先保留所有用户，尝试接订单。
接不上的用户，orders 字段都是 NULL。
所以用 o.id IS NULL 找出来。
```

找没有 paid 订单的活跃用户：

```sql
SELECT
  u.id,
  u.username
FROM users AS u
LEFT JOIN orders AS o
  ON o.user_id = u.id
 AND o.status = 'paid'
WHERE u.status = 'active'
  AND o.id IS NULL;
```

注意：`bob` 有 `cancelled` 订单，但也有 `paid` 订单，所以他不是“没有 paid 订单”的用户。

### 3. `COUNT(*)` 和 `COUNT(o.id)` 的区别

在 `LEFT JOIN` 里：

```sql
COUNT(*)
```

会统计 JOIN 后的行数。即使右表没有匹配，左表也会保留一行，所以可能把“没有订单的用户”算成 1。

更常用的是：

```sql
COUNT(o.id)
```

因为 `o.id` 是右表主键，右表没匹配时是 `NULL`，`COUNT(o.id)` 不统计 `NULL`。

### 4. `WHERE` 不能直接使用聚合结果

错误示例：

```sql
SELECT
  u.id,
  u.username,
  COUNT(o.id) AS order_cnt
FROM users AS u
LEFT JOIN orders AS o ON u.id = o.user_id
WHERE order_cnt = 0
GROUP BY u.id, u.username;
```

原因：`WHERE` 执行时，`order_cnt` 这个别名还没有生成。

错误示例：

```sql
WHERE COUNT(o.id) = 0
```

原因：`WHERE` 执行时还没有分组聚合结果。

正确写法：

```sql
SELECT
  u.id,
  u.username,
  COUNT(o.id) AS order_cnt
FROM users AS u
LEFT JOIN orders AS o ON u.id = o.user_id
GROUP BY u.id, u.username
HAVING COUNT(o.id) = 0;
```

或者：

```sql
HAVING order_cnt = 0
```

### 5. `SUM(CASE WHEN ... THEN ... ELSE ... END)` 的结构

用于：

```text
保留所有左表记录，但只统计满足条件的右表记录。
```

例如所有商品的已支付销量：

```sql
SELECT
  p.id,
  p.name,
  COALESCE(SUM(
    CASE WHEN o.id IS NOT NULL THEN oi.quantity ELSE 0 END
  ), 0) AS sold_quantity
FROM products AS p
LEFT JOIN order_items AS oi ON oi.product_id = p.id
LEFT JOIN orders AS o
  ON o.id = oi.order_id
 AND o.status = 'paid'
GROUP BY p.id, p.name
ORDER BY sold_quantity DESC, p.id;
```

注意顺序：

```text
SUM 在外面，CASE 在里面。
```

意思是：

```text
每一行先判断要不要计入销量，再把结果加总。
```

### 6. ORDER BY 和 GROUP BY 中多个字段的作用

`ORDER BY available_stock ASC, p.id`：

```text
先按 available_stock 升序。
如果库存相同，再按 p.id 升序。
```

第二个排序字段用于让结果稳定，特别是分页时很重要。

`GROUP BY u.id, u.username`：

```text
按 (u.id, u.username) 这个组合分组。
```

在 `ONLY_FULL_GROUP_BY` 模式下，如果 `SELECT` 里有普通字段和聚合函数，普通字段通常要写进 `GROUP BY`。

## SQL 语句的逻辑执行顺序

SQL 的书写顺序和逻辑执行顺序不同。以目前已经出现过的语句为例，逻辑顺序大致是：

```text
1. FROM
2. JOIN
3. ON
4. WHERE
5. GROUP BY
6. 聚合函数 COUNT / SUM / AVG / MIN / MAX
7. HAVING
8. SELECT
9. DISTINCT
10. ORDER BY
11. LIMIT / OFFSET
```

### 1. FROM

确定主表。

```sql
FROM users AS u
```

想题目时先问：

```text
谁是主体？
是不是所有主体都要显示？
```

例如：

```text
所有用户 + 订单数 -> users 是主体
所有商品 + 销量 -> products 是主体
所有分类 + 销售额 -> categories 是主体
订单列表 -> orders 是主体
```

### 2. JOIN

把其他表接进来。

```sql
LEFT JOIN orders AS o
```

`INNER JOIN` 只保留匹配成功的数据。  
`LEFT JOIN` 保留左表全部数据。

### 3. ON

指定表之间如何匹配。

```sql
ON o.user_id = u.id
```

`ON` 里等号两边没有左右顺序要求：

```sql
ON o.user_id = u.id
ON u.id = o.user_id
```

这两种等价。

但是 `ON` 只能引用：

```text
已经出现过的表
当前正在 JOIN 的表
```

不能引用后面才出现的表。

`LEFT JOIN` 中，如果右表条件只是决定“能不能接上”，通常放在 `ON`：

```sql
LEFT JOIN orders AS o
  ON o.user_id = u.id
 AND o.status = 'paid'
```

### 4. WHERE

过滤原始行。

```sql
WHERE u.status = 'active'
```

`WHERE` 发生在分组和聚合之前，所以不能写：

```sql
WHERE COUNT(o.id) = 0
```

也不能依赖 `SELECT` 里刚起的别名：

```sql
WHERE order_cnt = 0
```

除非这个别名来自更外层查询。

### 5. GROUP BY

把行分组。

```sql
GROUP BY u.id, u.username
```

常见场景：

```text
每个用户的订单数
每个商品的销量
每个分类的销售额
每天的订单金额
```

### 6. 聚合函数

在分组后计算：

```sql
COUNT(o.id)
SUM(o.total_amount)
AVG(p.price)
MIN(p.price)
MAX(p.price)
```

`COUNT(o.id)` 不统计 `NULL`，适合 LEFT JOIN 后统计右表匹配数量。

`SUM(...)` 如果没有可加的行，结果可能是 `NULL`，常搭配：

```sql
COALESCE(SUM(...), 0)
```

### 7. HAVING

过滤分组后的统计结果。

```sql
HAVING COUNT(o.id) = 0
```

`WHERE` 和 `HAVING` 的区别：

```text
WHERE：分组前过滤原始行。
HAVING：分组后过滤统计结果。
```

### 8. SELECT

决定最终输出哪些列，并创建别名。

```sql
SELECT
  u.id,
  u.username,
  COUNT(o.id) AS order_cnt
```

因为 `SELECT` 比 `WHERE` 晚执行，所以 `WHERE order_cnt = 0` 不可用。

### 9. DISTINCT

对最终结果去重。

```sql
SELECT DISTINCT
  u.id,
  u.username
```

适合避免一个用户因为多条订单而出现多行。

例如“有取消订单的用户”，如果一个用户有多条取消订单，不加 `DISTINCT` 会出现多行同一个用户。

### 10. ORDER BY

排序。

```sql
ORDER BY total_sales DESC, c.id
```

多个字段表示：

```text
先按第一个字段排；第一个字段相同，再按第二个字段排。
```

### 11. LIMIT / OFFSET

截取结果，用于 Top N 或分页。

```sql
LIMIT 3;
```

```sql
LIMIT 20 OFFSET 40;
```

分页时最好有稳定排序：

```sql
ORDER BY created_at DESC, id DESC
```

## 从需求到 SQL 的固定思考流程

以后遇到多表题，按这个顺序想：

```text
1. 题目要显示“所有 X”吗？
2. X 是哪张主体表？
3. 主体表到目标数据的关系路径是什么？
4. 用 INNER JOIN 还是 LEFT JOIN？
5. 条件是筛整行，还是只限制右表匹配？
6. 是否需要 GROUP BY？
7. 是否要统计满足条件的数量或金额？
8. 是否需要 COALESCE 把 NULL 变成 0？
9. 是否需要 ORDER BY 的第二字段稳定排序？
```

例子：

```text
所有分类及已支付销售额
```

分析：

```text
1. “所有分类” -> 主体是 categories
2. 要保留所有分类 -> LEFT JOIN
3. 路径：categories -> products -> order_items -> orders
4. “已支付”是右表 orders 的匹配条件 -> 放 ON
5. “销售额”是聚合 -> GROUP BY categories
6. 没销量显示 0 -> COALESCE
```

对应 SQL：

```sql
SELECT
  c.id,
  c.name,
  COALESCE(SUM(
    CASE WHEN o.id IS NOT NULL THEN oi.quantity * oi.unit_price ELSE 0 END
  ), 0) AS total_sales
FROM categories AS c
LEFT JOIN products AS p ON p.category_id = c.id
LEFT JOIN order_items AS oi ON oi.product_id = p.id
LEFT JOIN orders AS o
  ON o.id = oi.order_id
 AND o.status = 'paid'
GROUP BY c.id, c.name
ORDER BY total_sales DESC, c.id;
```

## 今日复盘结论

今天最难的地方集中在三个点：

```text
1. LEFT JOIN 的右表条件放 ON 还是 WHERE。
2. 聚合后的结果要用 HAVING 过滤，不是 WHERE。
3. 多表统计时，业务口径比语法更重要，例如“销售额”通常只统计 paid 订单。
```

这三个点都不是背一次就能熟的内容。后面做 Day 4 的子查询、CTE、窗口函数时，它们还会反复出现；现在能发现这些问题，说明你已经开始从“写语句”进入“判断结果是否符合业务”的阶段了。

