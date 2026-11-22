USE sakila;

CREATE INDEX idx_payment_date         ON payment (payment_date);
CREATE INDEX idx_rental_date_cust_inv ON rental (rental_date, customer_id, inventory_id);
CREATE INDEX idx_inventory_film       ON inventory (inventory_id, film_id);

EXPLAIN ANALYZE
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
