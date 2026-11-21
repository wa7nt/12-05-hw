# Домашнее задание к занятию «SQL. Часть 2»

> Запросы приведены в синтаксисе MySQL (как требуется в курсе). Проверка выполнена локально в SQLite 3.39.5 на БД Sakila (все запросы, кроме задания 3, полностью переносимы; в задании 3 `MONTH()` заменён на `strftime('%m', ...)`).

---

### Задание 1

Одним запросом получите информацию о магазине, в котором обслуживается более 300 покупателей, и выведите в результат следующую информацию:
- фамилия и имя сотрудника из этого магазина;
- город нахождения магазина;
- количество пользователей, закреплённых в этом магазине.

**Решение:**

```sql
SELECT
    s.last_name,
    s.first_name,
    ci.city,
    COUNT(cu.customer_id) AS customer_count
FROM store st
JOIN staff s     ON st.manager_staff_id = s.staff_id
JOIN address ad  ON st.address_id = ad.address_id
JOIN city ci     ON ad.city_id = ci.city_id
JOIN customer cu ON st.store_id = cu.store_id
GROUP BY st.store_id
HAVING COUNT(cu.customer_id) > 300;
```

**Результат:**

```
last_name  first_name  city        customer_count
---------  ----------  ----------  --------------
Hillyer    Mike        Lethbridge  326
```

---

### Задание 2

Получите количество фильмов, продолжительность которых больше средней продолжительности всех фильмов.

**Решение:**

```sql
SELECT COUNT(*) AS film_count
FROM film
WHERE length > (SELECT AVG(length) FROM film);
```

**Результат:**

```
film_count
----------
489
```

---

### Задание 3

Получите информацию, за какой месяц была получена наибольшая сумма платежей, и добавьте информацию по количеству аренд за этот месяц.

**Решение (MySQL):**

```sql
SELECT
    MONTH(payment_date) AS month,
    SUM(amount)         AS total_amount,
    COUNT(rental_id)    AS rental_count
FROM payment
GROUP BY MONTH(payment_date)
ORDER BY total_amount DESC
LIMIT 1;
```

**Решение (SQLite, на котором выполнялась проверка):**

```sql
SELECT
    strftime('%m', payment_date) AS month,
    ROUND(SUM(amount), 2)        AS total_amount,
    COUNT(rental_id)             AS rental_count
FROM payment
GROUP BY strftime('%m', payment_date)
ORDER BY total_amount DESC
LIMIT 1;
```

**Результат:**

```
month  total_amount  rental_count
-----  ------------  ------------
07     28373.89      6709
```

Наибольшая сумма платежей — в июле (месяц 07): 28 373.89 при 6 709 арендах.

---

## Дополнительные задания (со звёздочкой*)

### Задание 4*

Посчитайте количество продаж, выполненных каждым продавцом. Добавьте вычисляемую колонку «Премия». Если количество продаж превышает 8000, то значение в колонке будет «Да», иначе должно быть значение «Нет».

**Решение:**

```sql
SELECT
    s.staff_id,
    s.first_name,
    s.last_name,
    COUNT(p.payment_id) AS sales_count,
    CASE
        WHEN COUNT(p.payment_id) > 8000 THEN 'Да'
        ELSE 'Нет'
    END AS premium
FROM staff s
JOIN payment p ON s.staff_id = p.staff_id
GROUP BY s.staff_id;
```

**Результат:**

```
staff_id  first_name  last_name  sales_count  premium
--------  ----------  ---------  -----------  -------
1         Mike        Hillyer    8057         Да
2         Jon         Stephens   7992         Нет
```

---

### Задание 5*

Найдите фильмы, которые ни разу не брали в аренду.

**Решение:**

```sql
SELECT f.film_id, f.title
FROM film f
LEFT JOIN inventory i ON f.film_id = i.film_id
LEFT JOIN rental r    ON i.inventory_id = r.inventory_id
WHERE r.rental_id IS NULL;
```

**Результат (42 фильма):**

```
film_id  title
-------  ----------------------
1        ACADEMY DINOSAUR
14       ALICE FANTASIA
33       APOLLO TEEN
36       ARGONAUTS TOWN
38       ARK RIDGEMONT
41       ARSENIC INDEPENDENCE
87       BOONDOCK BALLROOM
108      BUTCH PANTHER
128      CATCH AMISTAD
144      CHINATOWN GLADIATOR
148      CHOCOLATE DUCK
171      COMMANDMENTS EXPRESS
192      CROSSING DIVORCE
195      CROWDS TELEMARK
198      CRYSTAL BREAKING
217      DAZED PUNK
221      DELIVERANCE MULHOLLAND
318      FIREHOUSE VIETNAM
325      FLOATS GARDEN
332      FRANKENSTEIN STRANGER
359      GLADIATOR WESTWARD
386      GUMP DATE
404      HATE HANDICAP
419      HOCUS FRIDA
495      KENTUCKIAN GIANT
497      KILL BROTHERHOOD
607      MUPPET MILE
642      ORDER BETRAYED
669      PEARL DESTINY
671      PERDITION FARGO
701      PSYCHO SHRUNK
712      RAIDERS ANTITRUST
713      RAINBOW SHOCK
742      ROOF CHAMPION
801      SISTER FREDDY
802      SKY MIRACLE
860      SUICIDES SILENCE
874      TADPOLE PARK
909      TREASURE COMMAND
943      VILLAIN DESPERATE
950      VOLUME HOUSE
954      WAKE JAWS
955      WALLS ARTIST
```
