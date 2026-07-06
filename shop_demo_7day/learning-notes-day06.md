# Day 6 Notes: Transactions, Locks, and Consistency

今天的主题是从“查询数据”进入“安全地修改数据”。核心不是多背几个命令，而是理解一组相关写操作如何保证：

```text
要么全部成功，要么全部不发生。
```

这就是事务最重要的价值。

## 1. 今天学到的核心模型

可以先把事务类比成一个“可撤销的修改区”：

```text
START TRANSACTION：打开一个可撤销的修改区。
COMMIT：确认无误，把修改正式保存。
ROLLBACK：撤销当前事务里还没有提交的所有修改。
```

更准确地说：

```text
ROLLBACK 只能撤销当前事务中尚未 COMMIT 的修改。
一旦 COMMIT，事务结束，修改正式进入数据库。
```

所以如果一个事务里有多条 SQL：

```sql
START TRANSACTION;

INSERT INTO orders ...;
INSERT INTO order_items ...;
UPDATE inventory ...;

ROLLBACK;
```

即使前两条 SQL 已经执行成功，只要还没有 `COMMIT`，`ROLLBACK` 都会把它们一起撤销。

这不是缺点，而是事务的目的：避免留下半成功的数据。

下单场景里，不能出现：

```text
订单创建成功
订单明细创建成功
库存扣减失败
```

否则系统就进入了不可信状态。

## 2. ROLLBACK 和 COMMIT 的区别

`ROLLBACK` 示例：

```sql
START TRANSACTION;

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_ROLLBACK_DEMO_MANUAL', 1, 49.00, 'created');

SELECT id, order_no, status
FROM orders
WHERE order_no = 'OD_ROLLBACK_DEMO_MANUAL';

ROLLBACK;

SELECT id, order_no, status
FROM orders
WHERE order_no = 'OD_ROLLBACK_DEMO_MANUAL';
```

现象：

```text
ROLLBACK 前能查到。
ROLLBACK 后查不到。
```

`COMMIT` 示例：

```sql
START TRANSACTION;

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_COMMIT_DEMO_MANUAL', 1, 49.00, 'created');

COMMIT;

SELECT id, order_no, status
FROM orders
WHERE order_no = 'OD_COMMIT_DEMO_MANUAL';
```

注意：如果 `COMMIT` 后查的是之前已经被 `ROLLBACK` 的订单号，例如：

```sql
WHERE order_no = 'OD_ROLLBACK_DEMO_MANUAL'
```

那结果仍然是空。这不是 `COMMIT` 没成功，而是查错了记录。

## 3. 没有 START TRANSACTION 时会怎样

MySQL 默认通常是自动提交模式：

```sql
SELECT @@autocommit;
```

如果结果是 `1`，表示：

```text
每条独立的 INSERT / UPDATE / DELETE 执行成功后会自动 COMMIT。
```

例如没有显式事务时：

```sql
INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_AUTO_COMMIT_TEST', 1, 49.00, 'created');
```

MySQL 可以理解成自动做了：

```text
START TRANSACTION
INSERT ...
COMMIT
```

所以后面再执行：

```sql
ROLLBACK;
```

通常撤销不了刚才那条 `INSERT`，因为它已经自动提交了。

一个显式事务通常在以下情况结束：

```text
COMMIT：成功结束，保存修改。
ROLLBACK：失败结束，撤销修改。
连接断开：未提交事务通常会被回滚。
某些 DDL 语句：例如 CREATE TABLE / ALTER TABLE / DROP TABLE 可能触发隐式提交。
```

## 4. 创建订单事务拆解

创建订单时，重点不是只插入一张订单表，而是要把几张表作为一个整体修改：

```sql
START TRANSACTION;

UPDATE inventory
SET reserved_stock = reserved_stock + 1
WHERE product_id = 1
  AND stock - reserved_stock >= 1;

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD202606240001', 3, 49.00, 'created');

SET @new_order_id = LAST_INSERT_ID();

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (@new_order_id, 1, 1, 49.00);

INSERT INTO operation_logs (actor, action, target_type, target_id, detail)
VALUES ('system', 'create_order', 'orders', @new_order_id, 'transaction commit demo');

COMMIT;
```

业务拆解：

```text
1. 库存足够，预占 1 件。
2. 创建订单主表。
3. 取得刚创建的订单 id。
4. 创建订单明细。
5. 写操作日志。
6. 一起提交。
```

### UPDATE 的执行理解

这句：

```sql
UPDATE inventory
SET reserved_stock = reserved_stock + 1
WHERE product_id = 1
  AND stock - reserved_stock >= 1;
```

可以理解为：

```text
先用旧值判断 WHERE。
再对通过筛选的行执行 SET。
```

所以：

```sql
AND stock - reserved_stock >= 1
```

用的是更新前的 `stock` 和更新前的 `reserved_stock`。

和 Verilog 类比时，`SET` 不完全等于持续 `assign`，更像：

```verilog
if (product_id == 1 && stock - reserved_stock >= 1) begin
  reserved_stock <= reserved_stock + 1;
end
```

也就是对选中的存储行做一次写入。

### LAST_INSERT_ID()

`LAST_INSERT_ID()` 表示：

```text
当前连接中，最近一次成功 INSERT 产生的 AUTO_INCREMENT 自增 id。
```

例如：

```sql
INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_TEST', 3, 49.00, 'created');

SET @new_order_id = LAST_INSERT_ID();
```

含义是：

```text
把刚刚自动生成的 orders.id 保存到变量 @new_order_id 里。
```

后面插入订单明细时：

```sql
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (@new_order_id, 1, 1, 49.00);
```

就能让 `order_items.order_id` 正确指向刚创建的订单。

注意：

```text
LAST_INSERT_ID() 是当前连接级别的。
另一个 MySQL 终端插入数据，不会影响当前连接拿到的值。
```

## 5. 支付事务拆解

支付流程会推进订单状态、扣真实库存、释放预占库存、写支付记录，所以必须放进事务。

核心 SQL：

```sql
START TRANSACTION;

SELECT product_id, stock, reserved_stock
FROM inventory
WHERE product_id = 1
FOR UPDATE;

UPDATE orders
SET status = 'paid', paid_at = CURRENT_TIMESTAMP
WHERE order_no = 'OD202606240001'
  AND status = 'created';

UPDATE inventory
SET stock = stock - 1,
    reserved_stock = reserved_stock - 1
WHERE product_id = 1
  AND reserved_stock >= 1;

INSERT INTO payments (order_id, payment_no, amount, channel, status)
SELECT id, 'PAY202606240001', total_amount, 'wechat', 'success'
FROM orders
WHERE order_no = 'OD202606240001';

COMMIT;
```

库存变化模型：

```text
创建订单阶段：reserved_stock + 1。
支付成功阶段：stock - 1，同时 reserved_stock - 1。
```

这表示：

```text
未支付时只是预占库存。
支付后才真正扣减库存。
```

## 6. FOR UPDATE 锁实验观察

数据库里一般说“加锁”，不是“锁存”。锁的目的不是存储信号，而是防止多个事务同时修改同一份关键数据。

什么时候要考虑加锁：

```text
如果要先读一个值，再根据这个值决定后续怎么改，而且这个值可能被别人同时改，就需要考虑加锁。
```

常见场景：

```text
库存
余额
优惠券数量
座位余量
秒杀名额
订单状态流转
支付状态
```

`SELECT ... FOR UPDATE` 的含义：

```text
我现在先读这行，但马上要改，所以先把这行锁住。
其他事务如果想更新同一行，需要等我 COMMIT 或 ROLLBACK。
```

双终端实验：

终端 A：

```sql
USE shop_demo;

START TRANSACTION;

SELECT product_id, stock, reserved_stock
FROM inventory
WHERE product_id = 3
FOR UPDATE;
```

先不要提交。

终端 B：

```sql
USE shop_demo;

UPDATE inventory
SET reserved_stock = reserved_stock + 1
WHERE product_id = 3;
```

现象：

```text
终端 B 会等待。
直到终端 A 执行 COMMIT 或 ROLLBACK 后，终端 B 才继续。
```

总结：

```text
普通 SELECT 不加写锁。
SELECT ... FOR UPDATE 是先读再锁。
UPDATE / DELETE 会自动锁住它们要修改的行。
```

### 为什么 inventory 显式加锁，但 orders 没有

示例里库存显式写了：

```sql
SELECT product_id, stock, reserved_stock
FROM inventory
WHERE product_id = 1
FOR UPDATE;
```

因为库存是高并发敏感数据，多个订单可能同时抢同一个商品。

而订单状态更新用了：

```sql
UPDATE orders
SET status = 'paid', paid_at = CURRENT_TIMESTAMP
WHERE order_no = 'OD202606240001'
  AND status = 'created';
```

`UPDATE` 本身会对要修改的订单行加锁，且 `status = 'created'` 防止重复状态推进。

但如果真实项目里是先查订单状态、金额、用户，再由应用程序判断是否更新，就更建议先锁订单：

```sql
SELECT id, status, total_amount
FROM orders
WHERE order_no = 'OD202606240001'
FOR UPDATE;
```

## 7. 约束、索引、事务、锁的分工

今天把几类保护机制串起来了：

```text
唯一索引：防止重复订单号、重复支付单号。
外键：防止订单指向不存在的用户，订单明细指向不存在的商品。
CHECK：防止库存数量进入明显非法状态。
事务：防止一组相关写操作只成功一半。
锁：防止并发事务同时修改关键行。
```

### 外键检查和事务顺序

同一个事务、同一个连接里，后面的 SQL 能看到前面还没 `COMMIT` 的修改。

所以这样可以：

```sql
START TRANSACTION;

INSERT INTO users (username, email)
VALUES ('frank', 'frank@example.com');

SET @user_id = LAST_INSERT_ID();

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_TEST_FK', @user_id, 49.00, 'created');

COMMIT;
```

因为 `orders.user_id` 引用的用户已经在当前事务中插入了。

但这样不行：

```sql
START TRANSACTION;

INSERT INTO orders (order_no, user_id, total_amount, status)
VALUES ('OD_BAD_FK', 999999, 49.00, 'created');

INSERT INTO users ...;

COMMIT;
```

MySQL 的外键检查通常是每条语句执行时立刻检查，不是等到 `COMMIT` 才统一检查。

所以插入顺序应该是：

```text
父表 -> 子表
users / products -> orders -> order_items -> payments
```

### INSERT 冲突

`INSERT` 是否会报错，取决于有没有违反约束：

```text
主键重复
唯一键重复
NOT NULL 字段插入 NULL
外键引用不存在的数据
CHECK 条件不满足
字段类型不兼容
字符串长度超过字段限制
```

如果 `INSERT` 的表不存在，MySQL 不会自动建表，会直接报错。建表必须显式使用：

```sql
CREATE TABLE ...
```

## 8. CHECK 怎么用

`CHECK` 用来限制一行数据必须满足某个条件。条件不满足，`INSERT` 或 `UPDATE` 会失败。

`inventory` 表里的规则：

```sql
CONSTRAINT chk_inventory_stock
CHECK (
  stock >= 0
  AND reserved_stock >= 0
  AND reserved_stock <= stock
)
```

含义：

```text
stock 不能小于 0。
reserved_stock 不能小于 0。
reserved_stock 不能大于 stock。
```

`CHECK` 适合管理单行内部规则：

```text
库存不能为负
冻结金额不能超过余额
年龄不能小于 0
价格不能为负
折扣必须在 0 到 1 之间
开始时间不能晚于结束时间
```

示例：

```sql
CREATE TABLE wallet (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  balance DECIMAL(10,2) NOT NULL,
  frozen_balance DECIMAL(10,2) NOT NULL DEFAULT 0,
  CONSTRAINT chk_wallet_balance
    CHECK (
      balance >= 0
      AND frozen_balance >= 0
      AND frozen_balance <= balance
    )
);
```

给已有表添加 `CHECK`：

```sql
ALTER TABLE inventory
ADD CONSTRAINT chk_inventory_stock
CHECK (
  stock >= 0
  AND reserved_stock >= 0
  AND reserved_stock <= stock
);
```

删除 `CHECK`：

```sql
ALTER TABLE inventory
DROP CHECK chk_inventory_stock;
```

`DESC inventory;` 看不到完整的 `CHECK` 规则。要看完整规则，用：

```sql
SHOW CREATE TABLE inventory;
```

如果刚刚报错，可以立刻执行：

```sql
SHOW WARNINGS;
```

有时能看到更具体的约束名，例如：

```text
Check constraint 'chk_inventory_stock' is violated.
```

## 9. information_schema 怎么用

`information_schema` 是 MySQL 自带的系统数据库。它不是业务数据，而是数据库结构说明书。

常用来查询：

```text
有哪些表
有哪些字段
有哪些索引
有哪些约束
有哪些外键关系
CHECK 规则具体是什么
```

查看当前库有哪些表：

```sql
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'shop_demo';
```

查看某张表有哪些字段：

```sql
SELECT
  column_name,
  column_type,
  is_nullable,
  column_default,
  column_key,
  extra
FROM information_schema.columns
WHERE table_schema = 'shop_demo'
  AND table_name = 'inventory'
ORDER BY ordinal_position;
```

查看约束列表：

```sql
SELECT
  table_name,
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'shop_demo'
ORDER BY table_name, constraint_type, constraint_name;
```

查看 `CHECK` 具体内容：

```sql
SELECT
  constraint_name,
  check_clause
FROM information_schema.check_constraints
WHERE constraint_schema = 'shop_demo';
```

查看外键关系：

```sql
SELECT
  table_name,
  column_name,
  referenced_table_name,
  referenced_column_name,
  constraint_name
FROM information_schema.key_column_usage
WHERE table_schema = 'shop_demo'
  AND referenced_table_name IS NOT NULL
ORDER BY table_name, column_name;
```

查看索引：

```sql
SELECT
  table_name,
  index_name,
  seq_in_index,
  column_name,
  non_unique
FROM information_schema.statistics
WHERE table_schema = 'shop_demo'
ORDER BY table_name, index_name, seq_in_index;
```

使用习惯：

```text
DESC：快速看字段。
SHOW CREATE TABLE：看单张表完整建表规则。
SHOW INDEX：看单张表索引。
information_schema：系统化扫描整个库的结构、索引、约束和外键。
```

## 10. 取消订单事务练习

取消订单不能只改订单状态，还要释放预占库存，并写操作日志。

推荐使用变量，避免在脚本里到处手改订单号：

```sql
SET @target_order_no = 'OD_xxx';
```

取消订单事务骨架：

```sql
START TRANSACTION;

SELECT id, status
FROM orders
WHERE order_no = @target_order_no
FOR UPDATE;

UPDATE orders
SET status = 'cancelled'
WHERE order_no = @target_order_no
  AND status = 'created';

SELECT ROW_COUNT() AS updated_orders;

UPDATE inventory AS i
INNER JOIN order_items AS oi ON oi.product_id = i.product_id
INNER JOIN orders AS o ON o.id = oi.order_id
SET i.reserved_stock = i.reserved_stock - oi.quantity
WHERE o.order_no = @target_order_no
  AND o.status = 'cancelled'
  AND i.reserved_stock >= oi.quantity;

SELECT ROW_COUNT() AS updated_inventory_rows;

INSERT INTO operation_logs (actor, action, target_type, target_id, detail)
SELECT 'system', 'cancel_order', 'orders', id, 'cancel order and release reserved stock'
FROM orders
WHERE order_no = @target_order_no;

SELECT
  p.name,
  i.stock,
  i.reserved_stock,
  i.stock - i.reserved_stock AS available_stock
FROM inventory AS i
INNER JOIN products AS p ON p.id = i.product_id
INNER JOIN order_items AS oi ON oi.product_id = i.product_id
INNER JOIN orders AS o ON o.id = oi.order_id
WHERE o.order_no = @target_order_no;

COMMIT;
```

真实项目中不能只是保存脚本然后改 `order_no` 使用，还需要：

```text
检查订单是否存在。
检查订单状态是否允许取消。
检查当前用户是否有权限取消。
检查 UPDATE 影响行数。
检查库存释放是否符合预期。
失败时 ROLLBACK。
```

如果订单已经支付，不应该按 `created` 订单的逻辑直接取消。

## 11. ROW_COUNT() 的作用

`ROW_COUNT()` 表示：

```text
上一条 INSERT / UPDATE / DELETE 语句影响了多少行。
```

它和 MySQL 客户端里看到的：

```text
Query OK, 1 row affected
```

是同一类信息。

区别：

```text
客户端提示是给人看的。
ROW_COUNT() 可以被 SQL 或程序逻辑读取。
```

示例：

```sql
UPDATE orders
SET status = 'cancelled'
WHERE order_no = @target_order_no
  AND status = 'created';

SELECT ROW_COUNT() AS updated_orders;
```

如果结果是：

```text
1
```

表示确实更新了一行。

如果结果是：

```text
0
```

常见原因：

```text
order_no 不存在。
订单状态不是 created。
新值和旧值一样。
WHERE 条件没有匹配上。
```

注意：

```text
ROW_COUNT() 只看上一条修改语句。
中间不要插入其他 SELECT 再查 ROW_COUNT()。
```

## 12. 今天遇到的错误和原因

有一次把正确写法：

```sql
SET i.reserved_stock = i.reserved_stock - oi.quantity
```

误写成：

```sql
SET i.reserved_stock = i.reserved_stock = oi.quantity
```

这不会立刻报语法错误，但逻辑完全不同。

MySQL 会把：

```sql
i.reserved_stock = oi.quantity
```

当成一个比较表达式，结果是 `0` 或 `1`，然后赋值给 `reserved_stock`。

例如：

```text
原 reserved_stock = 5
oi.quantity = 2
```

错误 SQL 后可能变成：

```text
reserved_stock = (5 = 2) = 0
```

这类错误很危险，因为：

```text
SQL 语法合法。
事务可以 COMMIT。
但业务结果是错的。
```

如果在 `COMMIT` 前发现：

```sql
ROLLBACK;
```

然后重新执行正确事务。

如果在 `COMMIT` 后发现：

```text
不能再用 ROLLBACK 撤销。
只能开启新的修复操作。
```

而且修复时不能简单“把正确 SQL 再跑一遍”，因为正确 SQL 是基于当前错误状态继续计算的，可能越修越错。

更稳的做法：

```text
先查询当前状态。
根据业务事实确定正确目标值。
再用新的事务明确修复。
```

例如：

```sql
START TRANSACTION;

SELECT product_id, stock, reserved_stock
FROM inventory
WHERE product_id = 1
FOR UPDATE;

UPDATE inventory
SET reserved_stock = 正确值
WHERE product_id = 1;

COMMIT;
```

## 13. 接手项目时如何检查写操作是否安全

检查一段写操作时，可以按这个 checklist：

```text
这组写操作是否应该放在同一个事务里？
有没有唯一索引防止重复提交？
有没有外键防止引用不存在的数据？
有没有 CHECK 防止明显非法的数值？
有没有状态条件防止重复推进？
有没有库存、余额等数量保护条件？
是否需要 SELECT ... FOR UPDATE？
UPDATE / DELETE 后是否检查影响行数？
失败时是否会 ROLLBACK？
COMMIT 前是否检查关键最终状态？
```

不需要每一步都做人工查询，但关键节点应该检查：

```text
订单状态是否按预期变化。
库存或余额是否按预期变化。
ROW_COUNT() 是否符合预期。
是否违反约束。
```

学习阶段可以多查：

```sql
SELECT ...
```

真实项目里通常由后端代码读取影响行数、捕获异常、决定 `COMMIT` 或 `ROLLBACK`。

最后总结：

```text
事务不是为了保证 SQL 一定写对。
事务是为了让错误在 COMMIT 前有机会被发现并撤销。
COMMIT 前发现错：ROLLBACK，重新来。
COMMIT 后发现错：只能做新的修复事务。
```

