SELECT
    SUM(CASE WHEN m.type = 'index' THEN d.pgsize ELSE 0 END) AS index_bytes,
    SUM(CASE WHEN m.type = 'table' THEN d.pgsize ELSE 0 END) AS table_bytes,
    ROUND(100.0 * SUM(CASE WHEN m.type = 'index' THEN d.pgsize ELSE 0 END)
               / SUM(CASE WHEN m.type = 'table' THEN d.pgsize ELSE 0 END), 2) AS index_percent
FROM dbstat d
JOIN sqlite_master m ON d.name = m.name;
