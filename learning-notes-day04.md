# Day 4 Notes: Business Analysis Queries

今天的主题是从普通查询升级到业务分析型查询。核心能力不是背更多语法，而是学会把业务问题拆成几个清晰步骤，再用子查询、CTE 和窗口函数表达出来。

## 1. 子查询

子查询就是把一条 `SELECT` 的结果交给另一条 SQL 使用。

### 1.1 高于平均价的商品

```sql
SELECT id, name, price
FROM products
WHERE price > (
  SELECT AVG(price)
  FROM products
)
ORDER BY price DESC;
```

理解顺序：

1. 先执行子查询，算出商品平均价。
2. 外层查询找出价格高于平均价的商品。

### 1.2 有订单的用户

```sql
SELECT id, username
FROM users
WHERE id IN (
  SELECT user_id
  FROM orders
);
```

`IN` 需要子查询返回一组具体的值。这里返回的是一组 `user_id`。

### 1.3 没有订单的用户

```sql
SELECT u.id, u.username
FROM users AS u
WHERE NOT EXISTS (
  SELECT 1
  FROM orders AS o
  WHERE o.user_id = u.id
);
```

`EXISTS` / `NOT EXISTS` 只关心子查询有没有返回行，不关心返回什么列。

所以这里写：

```sql
SELECT 1
```

意思是：只检查是否存在符合条件的记录。

下面这些写法通常逻辑等价：

```sql
SELECT 1
SELECT user_id
SELECT *
```

但项目里常用 `SELECT 1`，因为它表达得很清楚：我只关心是否存在。

## 2. CTE

CTE 的形式是：

```sql
WITH 临时结果名 AS (
  SELECT ...
)
SELECT ...
FROM 临时结果名;
```

可以把 CTE 理解成：把一个查询结果临时命名，后面的正式查询可以像使用表一样引用它。

CTE 只在当前这一条 SQL 里有效，不会永久保存到数据库。

### 2.1 一个 CTE

统计每个用户的已支付订单数量和消费总额：

```sql
WITH paid_orders AS (
  SELECT
    user_id,
    COUNT(*) AS paid_order_count,
    SUM(total_amount) AS paid_amount
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
)
SELECT
  u.username,
  po.paid_order_count,
  po.paid_amount
FROM paid_orders AS po
INNER JOIN users AS u ON u.id = po.user_id
ORDER BY po.paid_amount DESC;
```

### 2.2 多个 CTE

多个 CTE 用逗号分隔：

```sql
WITH paid_items AS (
  SELECT
    oi.product_id,
    oi.quantity,
    oi.unit_price
  FROM orders AS o
  INNER JOIN order_items AS oi ON oi.order_id = o.id
  WHERE o.status = 'paid'
),
product_sales AS (
  SELECT
    product_id,
    SUM(quantity) AS sold_quantity,
    SUM(quantity * unit_price) AS sales_amount
  FROM paid_items
  GROUP BY product_id
)
SELECT
  p.name,
  ps.sold_quantity,
  ps.sales_amount
FROM product_sales AS ps
INNER JOIN products AS p ON p.id = ps.product_id
ORDER BY ps.sales_amount DESC;
```

这条 SQL 的业务拆法：

1. `paid_items`: 先筛出已支付订单明细。
2. `product_sales`: 再按商品统计销量和销售额。
3. 最终查询：补上商品名并排序。

## 3. 如何拆业务分析查询

遇到业务分析题时，先不要急着写 SQL。先回答 5 个问题：

1. 最终要显示哪些列？
2. 这些列分别来自哪些表？
3. 过滤条件是什么，属于哪张表？
4. 最终按什么粒度统计？
5. 是否需要先做一个中间粒度？

如果你脑子里出现了这些词：

```text
先……
再……
然后……
最后……
```

通常就适合用 CTE。

### 示例：每个分类的销售额

业务问题：

```text
统计每个分类的已支付销售额，并按销售额从高到低排序。
```

拆解：

```text
最终列：category_id, category_name, cat_sales_cnt, cat_total_amount
来源表：orders, order_items, products, categories
过滤条件：orders.status = 'paid'
最终粒度：每个分类一行
中间步骤：先筛已支付明细，再按商品统计，再按分类统计
```

SQL：

```sql
WITH paid_items AS (
  SELECT
    oi.product_id,
    oi.quantity,
    oi.unit_price
  FROM orders AS o
  INNER JOIN order_items AS oi ON oi.order_id = o.id
  WHERE o.status = 'paid'
),
product_sales AS (
  SELECT
    product_id,
    SUM(quantity) AS product_sales_cnt,
    SUM(quantity * unit_price) AS product_total_amount
  FROM paid_items
  GROUP BY product_id
),
category_sales AS (
  SELECT
    c.id AS category_id,
    c.name AS category_name,
    SUM(ps.product_sales_cnt) AS cat_sales_cnt,
    SUM(ps.product_total_amount) AS cat_total_amount
  FROM product_sales AS ps
  INNER JOIN products AS p ON p.id = ps.product_id
  INNER JOIN categories AS c ON c.id = p.category_id
  GROUP BY c.id, c.name
)
SELECT
  category_id,
  category_name,
  cat_sales_cnt,
  cat_total_amount
FROM category_sales
ORDER BY cat_total_amount DESC;
```

## 4. 窗口函数

窗口函数不会像 `GROUP BY` 那样把多行合并成一行。它会保留原始行，并在旁边新增一个计算结果。

核心语法：

```sql
函数名() OVER (
  PARTITION BY 分组字段
  ORDER BY 排序字段
)
```

可以这样理解：

```text
PARTITION BY: 分小组
ORDER BY: 每个小组内部排序
窗口函数: 在每个小组里编号、排名、累计
```

## 5. ROW_NUMBER, RANK, DENSE_RANK

### 5.1 ROW_NUMBER()

`ROW_NUMBER()` 是强制编号。

即使排序字段相同，也会给每一行不同编号：

```text
1, 2, 3, 4
```

最常见用途：

```text
每个用户最新一笔订单
每个分类最贵一个商品
每个商品最新一条库存记录
```

模板：

```sql
WITH ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY 分组字段
      ORDER BY 排序字段 DESC
    ) AS rn
  FROM 某张表
)
SELECT *
FROM ranked
WHERE rn = 1;
```

### 5.2 RANK()

`RANK()` 是比赛排名。

如果有并列，会跳号：

```text
A 100 -> 1
B  90 -> 2
C  90 -> 2
D  80 -> 4
```

### 5.3 DENSE_RANK()

`DENSE_RANK()` 也是排名，但并列后不跳号：

```text
A 100 -> 1
B  90 -> 2
C  90 -> 2
D  80 -> 3
```

选择规则：

```text
每组只取一条：ROW_NUMBER()
真实比赛名次：RANK()
连续档位排名：DENSE_RANK()
```

## 6. 每个用户最新订单

这是项目高频问题。写法是：先给每个用户的订单编号，再取编号为 1 的订单。

```sql
WITH paid_orders AS (
  SELECT
    id,
    user_id,
    order_no,
    status,
    total_amount,
    paid_at
  FROM orders
  WHERE status = 'paid'
),
ranked_paid_orders AS (
  SELECT
    po.*,
    ROW_NUMBER() OVER (
      PARTITION BY user_id
      ORDER BY paid_at DESC, id DESC
    ) AS rn
  FROM paid_orders AS po
)
SELECT
  u.username,
  rpo.order_no,
  rpo.status,
  rpo.total_amount,
  rpo.paid_at
FROM ranked_paid_orders AS rpo
INNER JOIN users AS u ON u.id = rpo.user_id
WHERE rpo.rn = 1
ORDER BY rpo.paid_at DESC;
```

注意：

```sql
ORDER BY paid_at DESC, id DESC
```

多加 `id DESC` 是为了在两个订单支付时间相同时，仍然有稳定排序。

## 7. 每个分类销售额最高的商品

拆解：

```text
第一步：paid_items，筛出已支付订单明细
第二步：product_sales，统计每个商品销售额
第三步：product_with_category，把商品销售额和分类关联起来
第四步：ranked_products，在每个分类内部按销售额排名
第五步：取 rn = 1
```

SQL：

```sql
WITH paid_items AS (
  SELECT
    oi.product_id,
    oi.quantity,
    oi.unit_price
  FROM orders AS o
  INNER JOIN order_items AS oi ON oi.order_id = o.id
  WHERE o.status = 'paid'
),
product_sales AS (
  SELECT
    product_id,
    SUM(quantity * unit_price) AS sales_amount
  FROM paid_items
  GROUP BY product_id
),
product_with_category AS (
  SELECT
    c.id AS category_id,
    c.name AS category_name,
    p.id AS product_id,
    p.name AS product_name,
    ps.sales_amount
  FROM product_sales AS ps
  INNER JOIN products AS p ON p.id = ps.product_id
  INNER JOIN categories AS c ON c.id = p.category_id
),
ranked_products AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY category_id
      ORDER BY sales_amount DESC, product_id DESC
    ) AS rn
  FROM product_with_category
)
SELECT
  category_id,
  category_name,
  product_name,
  sales_amount
FROM ranked_products
WHERE rn = 1
ORDER BY sales_amount DESC;
```

## 8. 用户消费总额排名

```sql
WITH user_paid_summary AS (
  SELECT
    user_id,
    COUNT(*) AS paid_order_count,
    SUM(total_amount) AS paid_amount,
    MAX(paid_at) AS latest_paid_at
  FROM orders
  WHERE status = 'paid'
  GROUP BY user_id
)
SELECT
  u.username,
  ups.paid_order_count,
  ups.paid_amount,
  ups.latest_paid_at,
  DENSE_RANK() OVER (
    ORDER BY ups.paid_amount DESC
  ) AS paid_rank
FROM user_paid_summary AS ups
INNER JOIN users AS u ON u.id = ups.user_id
ORDER BY paid_rank, u.id;
```

这条 SQL 综合了：

```text
CTE
GROUP BY
JOIN
DENSE_RANK()
```

是今天非常好的验收题。

## 9. 累计销售额

窗口函数也可以用来做累计。

```sql
WITH daily_sales AS (
  SELECT
    DATE(paid_at) AS sales_date,
    SUM(total_amount) AS daily_amount
  FROM orders
  WHERE status = 'paid'
  GROUP BY DATE(paid_at)
)
SELECT
  sales_date,
  daily_amount,
  SUM(daily_amount) OVER (
    ORDER BY sales_date
  ) AS running_amount
FROM daily_sales
ORDER BY sales_date;
```

这里：

```sql
SUM(daily_amount) OVER (ORDER BY sales_date)
```

表示按日期逐行累计。

## 10. 今日验收标准

今天学完后，需要能解释并写出：

```sql
WITH ... AS (...)
```

表示把一个查询结果临时命名。

```sql
ROW_NUMBER() OVER (...)
```

表示在窗口里给每行编号。

```sql
PARTITION BY user_id
```

表示按用户分成多个小窗口。

```sql
ORDER BY paid_at DESC
```

表示每个窗口内部按支付时间从新到旧排序。

```sql
WHERE rn = 1
```

表示取每组排序后的第一条。

## 11. 练习

### 练习 A

找出每个用户最近一笔已支付订单。

要求：

1. 用 CTE 筛出已支付订单。
2. 用 `ROW_NUMBER()` 按用户分组、按支付时间倒序编号。
3. 取 `rn = 1`。
4. JOIN `users` 显示用户名。

### 练习 B

找出每个分类销售额最高的商品。

要求：

1. 先筛出已支付订单明细。
2. 再按商品统计销售额。
3. 再关联商品和分类。
4. 用 `ROW_NUMBER()` 在每个分类里排名。
5. 取 `rn = 1`。

### 练习 C

找出每个用户的已支付订单数、消费总额、最近支付时间，并按消费总额排名。

要求：

1. 用 CTE 按 `user_id` 聚合。
2. JOIN `users` 显示用户名。
3. 用 `DENSE_RANK()` 按消费总额排名。
