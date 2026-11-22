USE sakila;

SELECT
    SUM(INDEX_LENGTH) AS total_index_size,
    SUM(DATA_LENGTH)  AS total_table_size,
    ROUND(SUM(INDEX_LENGTH) / SUM(DATA_LENGTH) * 100, 2) AS index_percent
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'sakila'
  AND TABLE_TYPE = 'BASE TABLE';
