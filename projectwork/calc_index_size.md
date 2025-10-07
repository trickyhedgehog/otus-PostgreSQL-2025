# Оценим размер GIN-индекса для полнотекстового поиска в PostgreSQL.


```sql
SELECT
    pg_size_pretty(SUM(pg_relation_size(i.oid))) AS total_index_size
FROM pg_class t
         JOIN pg_inherits inh ON inh.inhrelid = t.oid
         JOIN pg_class p ON inh.inhparent = p.oid
         JOIN pg_index ix ON t.oid = ix.indrelid
         JOIN pg_class i ON i.oid = ix.indexrelid
WHERE p.relname = 'snippets';
-- 443 MB
```

## Для мониторинга в реальном времени

```sql
-- Быстрый запрос для регулярного мониторинга
SELECT
    pg_size_pretty(SUM(pg_total_relation_size(t.oid))) AS total_size,
    pg_size_pretty(SUM(pg_relation_size(t.oid))) AS total_data,
    pg_size_pretty(SUM(pg_indexes_size(t.oid))) AS total_indexes,
    ROUND(100.0 * SUM(pg_indexes_size(t.oid)) / 
          NULLIF(SUM(pg_total_relation_size(t.oid)), 0), 1) AS index_overhead_percent
FROM pg_class t
JOIN pg_inherits inh ON inh.inhrelid = t.oid
JOIN pg_class p ON inh.inhparent = p.oid
WHERE p.relname = 'snippets';
```


## 1️⃣ Детальная статистика по всем партициям

```sql
WITH parts AS (
    SELECT
        t.relname AS partition_name,
        t.oid,
        t.reltuples::bigint AS row_estimate,
        pg_relation_size(t.oid) AS data_size,
        COALESCE(SUM(pg_relation_size(i.oid)), 0) AS index_size
    FROM pg_class t
             JOIN pg_inherits inh ON inh.inhrelid = t.oid
             JOIN pg_class p ON inh.inhparent = p.oid
             LEFT JOIN pg_index ix ON t.oid = ix.indrelid
             LEFT JOIN pg_class i ON i.oid = ix.indexrelid
    WHERE p.relname = 'snippets'
    GROUP BY t.relname, t.oid, t.reltuples
)
SELECT
    partition_name,
    row_estimate,
    pg_size_pretty(data_size) AS data_size,
    pg_size_pretty(index_size) AS index_size,
    pg_size_pretty(data_size + index_size) AS total_size,
    -- Процентное соотношение
    ROUND(100.0 * data_size / SUM(data_size) OVER(), 2) AS data_percent,
    ROUND(100.0 * index_size / SUM(index_size) OVER(), 2) AS index_percent
FROM parts
UNION ALL
SELECT
    'TOTAL',
    SUM(row_estimate),
    pg_size_pretty(SUM(data_size)),
    pg_size_pretty(SUM(index_size)),
    pg_size_pretty(SUM(data_size + index_size)),
    100.0,
    100.0
FROM parts
ORDER BY partition_name;
```

## 2️⃣ Упрощенный запрос с сортировкой по размеру

```sql
SELECT
    t.relname AS partition_name,
    pg_size_pretty(pg_relation_size(t.oid)) AS data_size,
    pg_size_pretty(pg_indexes_size(t.oid)) AS index_size,
    pg_size_pretty(pg_total_relation_size(t.oid)) AS total_size,
    pg_total_relation_size(t.oid) AS total_bytes
FROM pg_class t
         JOIN pg_inherits inh ON inh.inhrelid = t.oid
         JOIN pg_class p ON inh.inhparent = p.oid
WHERE p.relname = 'snippets'
ORDER BY total_bytes DESC;
```

## 3️⃣ С агрегацией по типам индексов

```sql
WITH index_details AS (
    SELECT
        t.relname AS partition_name,
        t.oid AS table_oid,
        i.relname AS index_name,
        pg_relation_size(i.oid) AS index_size,
        am.amname AS index_type
    FROM pg_class t
             JOIN pg_inherits inh ON inh.inhrelid = t.oid
             JOIN pg_class p ON inh.inhparent = p.oid
             JOIN pg_index ix ON t.oid = ix.indrelid
             JOIN pg_class i ON i.oid = ix.indexrelid
             JOIN pg_am am ON i.relam = am.oid
    WHERE p.relname = 'snippets'
)
SELECT
    partition_name,
    pg_size_pretty(SUM(index_size)) AS total_index_size,
    COUNT(*) AS index_count,
    -- Разбивка по типам индексов
    SUM(CASE WHEN index_type = 'gin' THEN index_size ELSE 0 END) AS gin_size,
    SUM(CASE WHEN index_type = 'btree' THEN index_size ELSE 0 END) AS btree_size,
    pg_size_pretty(SUM(CASE WHEN index_type = 'gin' THEN index_size ELSE 0 END)) AS gin_size_pretty
FROM index_details
GROUP BY partition_name
ORDER BY SUM(index_size) DESC;
```

## Полная статистика с прогресс-баром

```sql
WITH partition_stats AS (
    SELECT
        t.relname AS partition_name,
        t.reltuples::bigint AS estimated_rows,
        pg_relation_size(t.oid) AS data_size,
        pg_indexes_size(t.oid) AS index_size,
        pg_total_relation_size(t.oid) AS total_size
    FROM pg_class t
             JOIN pg_inherits inh ON inh.inhrelid = t.oid
             JOIN pg_class p ON inh.inhparent = p.oid
    WHERE p.relname = 'snippets'
),
totals AS (
    SELECT
        SUM(data_size) AS total_data,
        SUM(index_size) AS total_index,
        SUM(total_size) AS grand_total
    FROM partition_stats
)
SELECT
    ps.partition_name,
    ps.estimated_rows,
    pg_size_pretty(ps.data_size) AS data_size,
    pg_size_pretty(ps.index_size) AS index_size,
    pg_size_pretty(ps.total_size) AS total_size,
    -- Процент от общего размера
    ROUND(100.0 * ps.total_size / t.grand_total, 1) AS percent_of_total,
    -- Визуальный прогресс-бар
    REPEAT('█', GREATEST(1, (100.0 * ps.total_size / t.grand_total)::int / 5)) AS visual_bar
FROM partition_stats ps, totals t
ORDER BY ps.total_size DESC;
```