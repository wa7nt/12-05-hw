EXPLAIN QUERY PLAN
SELECT DISTINCT
       c.last_name || ' ' || c.first_name AS name,
       SUM(p.amount) OVER (PARTITION BY c.customer_id, f.title) AS total
FROM payment p, rental r, customer c, inventory i, film f
WHERE date(p.payment_date) = '2005-07-30'
  AND p.payment_date = r.rental_date
  AND r.customer_id = c.customer_id
  AND i.inventory_id = r.inventory_id;

EXPLAIN QUERY PLAN
SELECT DISTINCT
       c.last_name || ' ' || c.first_name AS name,
       SUM(p.amount) OVER (PARTITION BY c.customer_id, f.title) AS total
FROM payment p
JOIN rental r    ON p.payment_date = r.rental_date
JOIN customer c  ON r.customer_id = c.customer_id
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f      ON i.film_id = f.film_id
WHERE p.payment_date >= '2005-07-30 00:00:00'
  AND p.payment_date <  '2005-07-31 00:00:00';
