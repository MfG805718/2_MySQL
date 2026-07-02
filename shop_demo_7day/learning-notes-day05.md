# Day 5 Notes: Indexes and EXPLAIN

今天的主题是索引和执行计划。前 4 天已经能把业务需求写成 SQL，今天开始理解：同一条 SQL 为什么有的快、有的慢，以及如何用 `SHOW INDEX` 和 `EXPLAIN` 判断查询有没有用上合适的索引。

## 1. SHOW INDEX 怎么看

`SHOW INDEX FROM table_name;` 用来查看一张表上有哪些索引，以及每个索引由哪些字段组成。

重点列：

```text
Table: 索引属于哪张表。
Non_unique: 是否允许重复，0 表示不允许重复，1 表示允许重复。
Key_name: 索引名。
Seq_in_index: 当前字段在联合索引里的第几个位置。
Column_name: 索引包含的字段。
Cardinality: MySQL 估算的不同值数量，越高通常区分度越好。
Index_type: 索引类型，当前主要看到的是 BTREE。
Visible: 索引是否对优化器可见。
```

看索引时最重要的是：

```text
同一个 Key_name 如果出现多行，说明这是联合索引。
Seq_in_index 表示联合索引的字段顺序。
```

例如：

```text
idx_orders_user_created
  1 user_id
  2 created_at
```

表示：

```sql
(user_id, created_at)
```

不是两个独立索引，而是一个按 `user_id`、`created_at` 顺序组织的联合索引。

## 2. orders 表索引理解

`orders` 表里当前主要有这些索引：

```text
PRIMARY (id)
```

`id` 是主键，不允许重复，适合按订单 id 精确查询一条记录。

```text
uk_orders_order_no (order_no)
```

`order_no` 是唯一索引，不允许重复，适合按订单号查询订单。

```text
idx_orders_user_created (user_id, created_at)
```

联合索引，先按 `user_id` 排，再按 `created_at` 排。适合：

```sql
WHERE user_id = ?
ORDER BY created_at DESC
```

```text
idx_orders_status_created (status, created_at)
```

联合索引，先按 `status` 排，再按 `created_at` 排。适合后台按订单状态查看订单，并按时间排序。

```text
idx_orders_user_status_created (user_id, status, created_at)
```

三列联合索引，适合：

```sql
WHERE user_id = ?
  AND status = ?
ORDER BY created_at DESC
```

这个索引既能帮助过滤，也能帮助排序。

## 3. products 表索引理解

`products` 表里当前有这些索引：

```text
PRIMARY (id)
```

`id` 是主键，不允许重复，适合通过商品 id 精确查询商品。

```text
uk_products_sku (sku)
```

`sku` 是唯一索引，不允许重复，适合通过商品业务编号查询商品。

```text
idx_products_category (category_id)
```

普通索引，允许重复，适合查询某个分类下的商品。

```text
idx_products_status_price_id (status, price, id)
```

联合索引，内部顺序是：

```text
先按 status 排
status 相同的里面再按 price 排
status 和 price 都相同的里面再按 id 排
```

适合商品列表页：

```sql
WHERE status = 'active'
  AND price BETWEEN 50 AND 200
ORDER BY price, id
```

其中 `id` 放在最后可以让排序更稳定，也更适合分页。

## 4. 联合索引是什么

联合索引不是给多个字段分别建索引，而是把多个字段按固定顺序做成一条组合查询路径。

例如：

```sql
(user_id, status, created_at)
```

可以理解为：

```text
先按 user_id 排
user_id 相同的里面再按 status 排
user_id 和 status 都相同的里面再按 created_at 排
```

它适合：

```sql
WHERE user_id = ?
```

```sql
WHERE user_id = ?
  AND status = ?
```

```sql
WHERE user_id = ?
  AND status = ?
ORDER BY created_at DESC
```

它不太适合：

```sql
WHERE status = ?
```

因为跳过了最左边的 `user_id`。

## 5. 最左前缀原则

联合索引的字段顺序很重要。对于：

```sql
(a, b, c)
```

比较理想的使用方式是：

```text
a
a, b
a, b, c
```

不能随便跳过 `a` 直接用 `b`，因为索引路径是从左到右组织的，搜索范围会一级一级更精确。

我的理解：

```text
如果绕过最左列，相当于没有按这条索引原本的路径进入，效率会下降。
```

更准确地说：

```text
不是绝对完全不能用，而是不能高效地按这条联合索引的有序路径定位。
```

## 6. EXPLAIN 两种格式

直接执行：

```sql
EXPLAIN
SELECT ...
```

当前 MySQL 可能显示 Tree 格式，只有一列 `EXPLAIN`。

例如：

```text
-> Limit: 10 row(s)
    -> Index lookup on orders using idx_orders_user_created (user_id = 1) (reverse)
```

这表示：

```text
使用 idx_orders_user_created 索引查 user_id = 1。
reverse 表示反向扫描索引，用来满足 ORDER BY created_at DESC。
```

如果想看到传统表格，可以写：

```sql
EXPLAIN FORMAT=TRADITIONAL
SELECT ...
```

传统格式重点看：

```text
type: 访问方式，ALL 通常表示全表扫描。
possible_keys: 可能使用的索引。
key: 实际使用的索引。
rows: 估计扫描的行数。
Extra: 额外信息，比如 Backward index scan、Using filesort、Using temporary。
```

## 7. 一条好的 EXPLAIN 示例

查询：

```sql
EXPLAIN FORMAT=TRADITIONAL
SELECT id, order_no, user_id, status, total_amount, created_at
FROM orders
WHERE user_id = 1
ORDER BY created_at DESC
LIMIT 10;
```

结果里：

```text
type = ref
key = idx_orders_user_created
rows = 2
Extra = Backward index scan
```

说明 MySQL 使用了：

```sql
(user_id, created_at)
```

这个联合索引。

这条查询没有出现 `Using filesort`，是好事。因为 MySQL 可以先定位 `user_id = 1`，再沿着索引里 `created_at` 的顺序反向扫描。

## 8. partitions 列是什么意思

`EXPLAIN` 里的 `partitions` 和窗口函数里的 `PARTITION BY` 不是一回事。

窗口函数里的：

```sql
PARTITION BY user_id
```

表示在查询结果里按用户分组计算。

`EXPLAIN` 里的 `partitions` 指的是 MySQL 的分区表信息。如果一张表按月份、年份等拆成多个物理分区，这一列会显示查询访问了哪些分区。

当前结果里：

```text
partitions = NULL
```

表示当前表不是分区表，或者没有涉及分区裁剪信息。现阶段可以先忽略。

## 9. Using filesort 和 Backward index scan

`Using filesort` 表示 MySQL 需要额外排序，不是直接按索引顺序拿到结果。

但没有出现 `Using filesort` 不代表没有排序需求，而是可能索引已经满足了排序。

例如：

```sql
WHERE user_id = 1
ORDER BY created_at DESC
```

如果使用：

```sql
(user_id, created_at)
```

MySQL 可以在 `user_id = 1` 的范围内按 `created_at` 反向读，这时 `Extra` 可能显示：

```text
Backward index scan
```

这是一个比较理想的信号。

## 10. GROUP BY 是否影响索引

`GROUP BY` 会影响索引使用。索引不仅能帮助 `WHERE` 过滤，也可能帮助 `ORDER BY` 排序和 `GROUP BY` 分组。

关键仍然是：

```text
GROUP BY 的字段顺序是否能从联合索引最左边开始匹配。
```

例如有索引：

```sql
(user_id, created_at)
```

这个查询可能受益：

```sql
SELECT user_id, COUNT(*)
FROM orders
GROUP BY user_id;
```

因为索引以 `user_id` 开头。

如果有索引：

```sql
(status, created_at)
```

这个查询可能受益：

```sql
SELECT status, COUNT(*)
FROM orders
GROUP BY status;
```

如果有索引：

```sql
(user_id, status, created_at)
```

这个查询可能受益：

```sql
SELECT user_id, status, COUNT(*)
FROM orders
GROUP BY user_id, status;
```

`GROUP BY` 常见的 `Extra` 信息：

```text
Using temporary: MySQL 需要临时表处理中间结果。
Using filesort: MySQL 需要额外排序。
Using index: 查询需要的列都在索引里，可能不需要回表。
```

## 11. 为什么可以为慢 SQL 专门建索引

实际项目里，可以根据高频、慢、重要的 SQL 专门设计索引。

例如：

```sql
SELECT id, order_no, total_amount, created_at
FROM orders
WHERE user_id = 2
  AND status = 'paid'
ORDER BY created_at DESC
LIMIT 10;
```

可以考虑：

```sql
CREATE INDEX idx_orders_user_status_created
ON orders(user_id, status, created_at);
```

因为：

```text
user_id 是等值过滤
status 是等值过滤
created_at 用于排序
```

但不能看到 `type = ALL` 就立刻加索引。需要先判断：

```text
这条 SQL 是否高频。
这张表是否足够大。
SQL 本身有没有更好的写法。
是否已有相近索引。
新增索引会不会带来写入成本和索引冗余。
```

## 12. SQL 写法也会影响索引

这个写法不够索引友好：

```sql
SELECT *
FROM orders
WHERE DATE(created_at) = '2026-06-20';
```

原因是对索引列 `created_at` 套了函数，MySQL 可能需要对每一行先计算：

```sql
DATE(created_at)
```

再比较日期。

更推荐写成范围查询：

```sql
SELECT *
FROM orders
WHERE created_at >= '2026-06-20'
  AND created_at < '2026-06-21';
```

这表示：

```text
从 2026-06-20 00:00:00 开始
到 2026-06-21 00:00:00 之前
```

这样可以直接使用原始字段 `created_at` 做范围扫描，更有利于使用索引。

查某一天、某一周、某一个月的数据时，优先使用这种半开区间：

```text
>= 开始时间
< 下一段开始时间
```

比 `BETWEEN '当天' AND '当天 23:59:59'` 更稳，因为不会漏掉小数秒。

## 13. 等值字段、范围字段和排序字段的顺序

常见经验：

```text
等值过滤字段放前面，范围字段或排序字段放后面。
```

但原因不是“等值字段 cardinality 一定更低”。

更核心的原因是：

```text
等值条件能把索引路径固定住。
范围条件一旦开始，后面的索引列就很难继续精确利用。
```

例如：

```sql
WHERE user_id = ?
  AND status = ?
ORDER BY created_at DESC
```

可以设计：

```sql
(user_id, status, created_at)
```

原因：

```text
user_id 等值过滤
status 等值过滤
created_at 排序
```

如果只有：

```sql
(user_id, status)
```

也能帮助过滤，但不能很好服务 `ORDER BY created_at DESC`。

更贴合的索引是：

```sql
(user_id, status, created_at)
```

## 14. Cardinality 的作用

`Cardinality` 是辅助判断，不是联合索引字段顺序的唯一依据。

例如：

```text
status 的 Cardinality 可能很低。
created_at 的 Cardinality 可能很高。
user_id 的 Cardinality 也可能很高。
```

但字段顺序主要还是看 SQL 的查询模式：

```text
是否等值过滤。
是否范围过滤。
是否排序。
是否高频。
是否能服务更多相近查询。
```

`status` 单独建索引可能价值不大，但放在：

```sql
(user_id, status, created_at)
```

里面就可能很有价值，因为它是在 `user_id` 已经缩小范围后继续筛选。

## 15. 今天的核心总结

今天最重要的理解：

```text
索引不是字段清单，而是有顺序的查询路径。
```

联合索引：

```text
从左到右组织数据。
搜索范围一级一级变精确。
不能随便跳过最左列。
```

`EXPLAIN` 的作用：

```text
观察 MySQL 实际怎么执行 SQL。
看它用了哪个索引。
看它大概要扫多少行。
看是否需要额外排序或临时表。
```

实际项目里设计索引时，不要问：

```text
这个字段要不要建索引？
```

而要问：

```text
项目里有没有高频 SQL 会按这组字段查询、排序或分组？
```

