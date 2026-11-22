# Домашнее задание к занятию «Индексы»

**Выполнил:** Haujs

> Запросы приведены в синтаксисе MySQL (как требуется в курсе). Проверка выполнена локально в SQLite 3.39.5 на БД Sakila: размеры — через виртуальную таблицу `dbstat`, планы — через `EXPLAIN QUERY PLAN`.

---

### Задание 1

Напишите запрос к учебной базе данных, который вернёт процентное отношение общего размера всех индексов к общему размеру всех таблиц.

**Решение (MySQL, база `sakila`):**

```sql
SELECT
    SUM(INDEX_LENGTH) AS total_index_size,
    SUM(DATA_LENGTH)  AS total_table_size,
    ROUND(SUM(INDEX_LENGTH) / SUM(DATA_LENGTH) * 100, 2) AS index_percent
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'sakila'
  AND TABLE_TYPE = 'BASE TABLE';
```

- `DATA_LENGTH` — размер данных таблиц;
- `INDEX_LENGTH` — размер индексов;
- `index_percent` — искомое процентное отношение.

**Проверка в SQLite (`dbstat`):**

```sql
SELECT
    SUM(CASE WHEN m.type = 'index' THEN d.pgsize ELSE 0 END) AS index_bytes,
    SUM(CASE WHEN m.type = 'table' THEN d.pgsize ELSE 0 END) AS table_bytes,
    ROUND(100.0 * SUM(CASE WHEN m.type = 'index' THEN d.pgsize ELSE 0 END)
               / SUM(CASE WHEN m.type = 'table' THEN d.pgsize ELSE 0 END), 2) AS index_percent
FROM dbstat d
JOIN sqlite_master m ON d.name = m.name;
```

**Результат (Sakila, SQLite):**

```
index_bytes  table_bytes  index_percent
-----------  -----------  -------------
2406400      3360768      71.6
```

Индексы занимают ≈ 71.6 % от размера данных таблиц.

---

### Задание 2

Выполните explain analyze следующего запроса:

```sql
select distinct concat(c.last_name, ' ', c.first_name), sum(p.amount) over (partition by c.customer_id, f.title)
from payment p, rental r, customer c, inventory i, film f
where date(p.payment_date) = '2005-07-30' and p.payment_date = r.rental_date and r.customer_id = c.customer_id and i.inventory_id = r.inventory_id
```

**План до оптимизации (реальный вывод `EXPLAIN QUERY PLAN`, SQLite):**

```
QUERY PLAN
|--CO-ROUTINE (subquery-2)
|  |--SCAN c USING INDEX sqlite_autoindex_customer_1
|  |--SEARCH r USING INDEX idx_rental_fk_customer_id (customer_id=?)
|  |--SEARCH i USING COVERING INDEX sqlite_autoindex_inventory_1 (inventory_id=?)
|  |--SCAN f
|  |--SEARCH p USING AUTOMATIC PARTIAL COVERING INDEX (payment_date=?)
|  `--USE TEMP B-TREE FOR RIGHT PART OF ORDER BY
|--SCAN (subquery-2)
`--USE TEMP B-TREE FOR DISTINCT
```

> В MySQL для получения такого плана используется `EXPLAIN ANALYZE <запрос>`. Здесь план получен в SQLite (эквивалент `EXPLAIN`), вывод приведён выше.

**Узкие места:**

1. **`date(p.payment_date) = '2005-07-30'`** — функция над колонкой мешает использованию обычного индекса по `payment_date`: оптимизатор вынужден строить *временный* (`AUTOMATIC PARTIAL COVERING INDEX`) индекс прямо во время запроса. Нужно заменить на диапазон `payment_date >= '2005-07-30' AND payment_date < '2005-07-31'`.
2. **`SCAN f` — таблица `film` не соединена с остальными.** В `WHERE` есть `i.inventory_id = r.inventory_id`, но нет `i.film_id = f.film_id`. Возникает декартово произведение: каждая запись payment умножается на все 1000 фильмов. Это главная причина медленной работы и, более того, **неверного результата**: `SUM(p.amount) OVER (PARTITION BY c.customer_id, f.title)` считает сумму по всем фильмам сразу, а не по фильму, который реально брали в аренду.
3. **`USE TEMP B-TREE FOR RIGHT PART OF ORDER BY` и `USE TEMP B-TREE FOR DISTINCT`** — две сортировки во временных структурах из-за оконной функции и `DISTINCT`.
4. **Устарый синтаксис join через запятые** — оптимизатору сложнее выбрать порядок соединения; в плане `customer` сканируется первым (`SCAN c`), хотя фильтр стоит по `payment`.
5. **Отсутствуют подходящие индексы** для фильтрации и соединений: `payment(payment_date)`, `rental(rental_date, customer_id, inventory_id)`, `inventory(inventory_id, film_id)`.

**Оптимизированный запрос (MySQL):**

```sql
SELECT DISTINCT
       CONCAT(c.last_name, ' ', c.first_name),
       SUM(p.amount) OVER (PARTITION BY c.customer_id, f.title) AS total
FROM payment p
JOIN rental r    ON p.payment_date = r.rental_date
JOIN customer c  ON r.customer_id = c.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f      ON i.film_id = f.film_id
WHERE p.payment_date >= '2005-07-30'
  AND p.payment_date <  '2005-07-31';
```

**Вариант для проверки в SQLite:**

```sql
SELECT DISTINCT
       c.last_name || ' ' || c.first_name,
       SUM(p.amount) OVER (PARTITION BY c.customer_id, f.title) AS total
FROM payment p
JOIN rental r    ON p.payment_date = r.rental_date
JOIN customer c  ON r.customer_id = c.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f      ON i.film_id = f.film_id
WHERE p.payment_date >= '2005-07-30 00:00:00'
  AND p.payment_date <  '2005-07-31 00:00:00';
```

**Что исправлено:**

- `date(p.payment_date) = ...` → диапазон, индекс по `payment_date` используется напрямую;
- добавлено недостающее условие `i.film_id = f.film_id` — убрано декартово произведение и исправлена логика суммы;
- явные `JOIN` вместо запятых; порядок обхода таблиц теперь начинается с `rental` по индексу.

**План после оптимизации (реальный вывод):**

```
QUERY PLAN
|--CO-ROUTINE (subquery-2)
|  |--SEARCH r USING COVERING INDEX idx_rental_uq (rental_date>? AND rental_date<?)
|  |--SEARCH c USING INDEX sqlite_autoindex_customer_1 (customer_id=?)
|  |--SEARCH i USING INDEX sqlite_autoindex_inventory_1 (inventory_id=?)
|  |--SEARCH f USING INDEX sqlite_autoindex_film_1 (film_id=?)
|  |--SEARCH p USING AUTOMATIC PARTIAL COVERING INDEX (payment_date=?)
|  `--USE TEMP B-TREE FOR ORDER BY
|--SCAN (subquery-2)
`--USE TEMP B-TREE FOR DISTINCT
```

Все Full scan исчезли (`SCAN f` → `SEARCH f USING INDEX ...`), поиск идёт по индексам.

**Рекомендуемые индексы (MySQL):**

```sql
CREATE INDEX idx_payment_date        ON payment (payment_date);
CREATE INDEX idx_rental_date_cust_inv ON rental (rental_date, customer_id, inventory_id);
CREATE INDEX idx_inventory_film      ON inventory (inventory_id, film_id);
```

**Замер производительности (SQLite, одна и та же машина):**

| Запрос | Время | Строк результата |
|--------|-------|------------------|
| до оптимизации | 11.143 c | 391 |
| после оптимизации | 0.019 c | 602 |

Ускорение ≈ в 580 раз. Количество строк изменилось, потому что исходный запрос из-за отсутствия `i.film_id = f.film_id` считал не сумму по конкретному фильму, а сумму клиента, повторенную для каждого из 1000 фильмов, после чего `DISTINCT` схлопывал их в 391 запись.

---

## Дополнительные задания (со звёздочкой*)

### Задание 3*

Самостоятельно изучите, какие типы индексов используются в PostgreSQL. Перечислите те индексы, которые используются в PostgreSQL, а в MySQL — нет.

**Решение:**

Общие для обеих СУБД: B-tree (тип по умолчанию и в MySQL InnoDB, и в PostgreSQL), Hash (в MySQL — только движком MEMORY; в PostgreSQL — отдельный тип доступа), полнотекстовый (в MySQL — `FULLTEXT`, в PostgreSQL — на базе GIN/GiST).

**Есть в PostgreSQL, но нет в MySQL:**

- **GiST** (Generalized Search Tree) — универсальный тип для геометрических типов, range-типов, full-text;
- **SP-GiST** (Space-Partitioned GiST) — для неравномерно распределённых данных (квадродеревья, k-d-деревья);
- **GIN** (Generalized Inverted Index) — инвертированный индекс для массивов, `jsonb`, full-text;
- **BRIN** (Block Range Index) — очень компактный индекс для больших таблиц с естественным порядком данных;
- **частичные индексы** (`CREATE INDEX ... WHERE <условие>`) — индексируют только подмножество строк;
- **индексы по выражениям** (`CREATE INDEX ... ON t (lower(col))`);
- **индексы с включёнными колонками** (`INCLUDE (...)`) — covering indexes;
- **bitmap-сканирование** — в MySQL отдельного типа индекса нет;
- **R-tree** в MySQL есть как `SPATIAL`, а в PostgreSQL аналогичная функциональность реализована через GiST, отдельного типа `R-tree` нет.

---

## Код

- [`sql/task1.sql`](sql/task1.sql) — запрос MySQL к `information_schema` (задание 1);
- [`sql/task1_sqlite.sql`](sql/task1_sqlite.sql) — проверка размера индексов через `dbstat` в SQLite;
- [`sql/task2_explain.sql`](sql/task2_explain.sql) — исходный запрос с `EXPLAIN ANALYZE`;
- [`sql/task2_optimized.sql`](sql/task2_optimized.sql) — оптимизированный запрос + `CREATE INDEX`;
- [`sql/task2_sqlite.sql`](sql/task2_sqlite.sql) — планы до/после оптимизации в SQLite.
