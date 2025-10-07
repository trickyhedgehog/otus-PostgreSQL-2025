SELECT u.user_id,
       p.headers ->> 'From'    AS "from",
       p.headers ->> 'To'      AS "to",
       p.headers ->> 'Subject' AS "subject"
FROM parts p
         JOIN messages m ON p.msg_id = m.msg_id
         JOIN tags t ON m.tag_id = t.tag_id
         JOIN users u ON t.user_id = u.user_id
WHERE p.headers ->> 'From' IS NOT NULL
  AND p.headers ->> 'To' IS NOT NULL
  AND p.headers ->> 'Subject' IS NOT NULL;

select analyze_partitions('snippets');
SELECT count(*) FROM snippets;

EXPLAIN ANALYSE
    SELECT msg_id, snippet
FROM snippets
WHERE fts @@ plainto_tsquery('russian', 'Зеленский')
  AND fts @@ plainto_tsquery('english', 'leggings');
-- [2025-09-08 12:11:17] 53 rows retrieved starting from 1 in 431 ms (execution: 19 ms, fetching: 412 ms)
-- +---------------------------------------------------------------------------------------------------------------------------------------+
-- |QUERY PLAN                                                                                                                             |
-- +---------------------------------------------------------------------------------------------------------------------------------------+
-- |Append  (cost=31.08..5514.29 rows=1846 width=1073) (actual time=0.231..39.544 rows=1784 loops=1)                                       |
-- |  ->  Bitmap Heap Scan on snippets_p0 snippets_1  (cost=31.08..569.46 rows=193 width=1060) (actual time=0.230..2.242 rows=195 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=186                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p0_fts_idx  (cost=0.00..31.03 rows=193 width=0) (actual time=0.194..0.194 rows=195 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p1 snippets_2  (cost=31.04..557.69 rows=186 width=1076) (actual time=0.259..1.247 rows=174 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=169                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p1_fts_idx  (cost=0.00..31.00 rows=186 width=0) (actual time=0.229..0.229 rows=174 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p2 snippets_3  (cost=31.12..586.15 rows=202 width=1084) (actual time=0.210..1.802 rows=199 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=192                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p2_fts_idx  (cost=0.00..31.07 rows=202 width=0) (actual time=0.181..0.181 rows=199 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p3 snippets_4  (cost=30.96..519.64 rows=171 width=1071) (actual time=0.204..1.107 rows=157 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=146                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p3_fts_idx  (cost=0.00..30.92 rows=171 width=0) (actual time=0.171..0.171 rows=157 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p4 snippets_5  (cost=30.97..525.57 rows=173 width=1074) (actual time=0.209..1.419 rows=176 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=165                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p4_fts_idx  (cost=0.00..30.93 rows=173 width=0) (actual time=0.176..0.176 rows=176 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p5 snippets_6  (cost=31.05..553.77 rows=187 width=1071) (actual time=0.692..26.346 rows=153 loops=1)|
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=151                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p5_fts_idx  (cost=0.00..31.00 rows=187 width=0) (actual time=0.651..0.651 rows=153 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p6 snippets_7  (cost=31.12..584.83 rows=200 width=1082) (actual time=0.284..1.514 rows=205 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=194                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p6_fts_idx  (cost=0.00..31.07 rows=200 width=0) (actual time=0.230..0.230 rows=205 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p7 snippets_8  (cost=30.96..519.64 rows=171 width=1074) (actual time=0.217..1.494 rows=169 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=159                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p7_fts_idx  (cost=0.00..30.92 rows=171 width=0) (actual time=0.190..0.190 rows=169 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p8 snippets_9  (cost=31.00..535.40 rows=178 width=1071) (actual time=0.202..1.078 rows=175 loops=1) |
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=165                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p8_fts_idx  (cost=0.00..30.96 rows=178 width=0) (actual time=0.171..0.171 rows=175 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |  ->  Bitmap Heap Scan on snippets_p9 snippets_10  (cost=31.03..552.91 rows=185 width=1065) (actual time=0.249..1.116 rows=181 loops=1)|
-- |        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
-- |        Heap Blocks: exact=169                                                                                                         |
-- |        ->  Bitmap Index Scan on snippets_p9_fts_idx  (cost=0.00..30.99 rows=185 width=0) (actual time=0.221..0.221 rows=181 loops=1)  |
-- |              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
-- |Planning Time: 4.084 ms                                                                                                                |
-- |Execution Time: 39.914 ms                                                                                                              |
-- +---------------------------------------------------------------------------------------------------------------------------------------+


SELECT
    pg_size_pretty(SUM(pg_relation_size(i.oid))) AS total_index_size
FROM pg_class t
         JOIN pg_inherits inh ON inh.inhrelid = t.oid
         JOIN pg_class p ON inh.inhparent = p.oid
         JOIN pg_index ix ON t.oid = ix.indrelid
         JOIN pg_class i ON i.oid = ix.indexrelid
WHERE p.relname = 'snippets';

-- размеры данных + индексов (то есть полный размер каждой партиции, как pg_total_relation_size)
-- + количество строк в каждой партиции (берём оценку из pg_class.reltuples, это быстро;
-- если нужен точный count(*) — будет медленнее).
WITH parts AS (
    SELECT
        t.relname AS partition_name, --  имя партиции (snippets_p0 … snippets_p9).
        t.oid,
        t.reltuples::bigint AS row_estimate, -- примерное число строк (берётся из статистики, обновляется после ANALYZE).
        pg_relation_size(t.oid) AS data_size, -- только данные (таблица без индексов).
        COALESCE(SUM(pg_relation_size(i.oid)), 0) AS index_size -- суммарный размер индексов.
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
    pg_size_pretty(data_size)   AS data_size,
    pg_size_pretty(index_size)  AS index_size,
    pg_size_pretty(data_size + index_size) AS total_size
FROM parts
UNION ALL
SELECT
    'TOTAL', -- итог по всей таблице snippets.
    SUM(row_estimate),
    pg_size_pretty(SUM(data_size)),
    pg_size_pretty(SUM(index_size)),
    pg_size_pretty(SUM(data_size + index_size)) -- полный размер (данные + индексы).
FROM parts
ORDER BY partition_name;


--EXPLAIN ANALYSE
SELECT msg_id,
       ts_headline('russian', snippet, plainto_tsquery('russian', 'Зеленский & leggings')) AS snippet
FROM snippets
WHERE fts @@ plainto_tsquery('russian', 'Зеленский & leggings')
LIMIT 50;


--EXPLAIN ANALYSE
SELECT msg_id,
       ts_headline('russian', snippet, websearch_to_tsquery('russian', 'Зеленский AND leggings')) AS snippet
FROM snippets
WHERE fts @@ websearch_to_tsquery('russian', 'Зеленский AND leggings')
LIMIT 50;
-- +------------------------------------------------------------------------------------------------------------------------------+
-- |QUERY PLAN                                                                                                                    |
-- +------------------------------------------------------------------------------------------------------------------------------+
-- |Bitmap Heap Scan on messages  (cost=49.05..6012.61 rows=1995 width=40) (actual time=4.588..367.284 rows=1977 loops=1)         |
-- |  Recheck Cond: (fts @@ '''Зеленск'' & ''leg'''::tsquery)                                                                     |
-- |  Heap Blocks: exact=1807                                                                                                     |
-- |  ->  Bitmap Index Scan on idx_messages_fts  (cost=0.00..48.56 rows=1995 width=0) (actual time=3.156..3.156 rows=1977 loops=1)|
-- |        Index Cond: (fts @@ '''Зеленск'' & ''leg'''::tsquery)                                                                 |
-- |Planning Time: 0.490 ms                                                                                                       |
-- |Execution Time: 367.381 ms                                                                                                    |
-- +------------------------------------------------------------------------------------------------------------------------------+
-- Индекс работает отлично, поиск по fts быстрый (~3 ms для индекса).
-- Главный узкий момент — ts_headline по ~2000 текстам (CPU-интенсивно).
-- websearch_to_tsquery не меняет план — это просто другой способ построить tsquery.

SELECT count(*) FROM messages; --203004

SELECT
    pg_size_pretty(SUM(pg_relation_size(i.oid))) AS total_index_size
FROM pg_class t
         JOIN pg_inherits inh ON inh.inhrelid = t.oid
         JOIN pg_class p ON inh.inhparent = p.oid
         JOIN pg_index ix ON t.oid = ix.indrelid
         JOIN pg_class i ON i.oid = ix.indexrelid
WHERE p.relname = 'snippets';
-- 443 MB

-- Размер индекса ~1.3KB на запись, что для полнотекстового индекса нормальный показатель.
-- Для дальнейшего роста таблицы стоит учитывать, что GIN-индекс увеличивается пропорционально количеству токенов в snippet.
-- Если появятся большие тексты (MIME-сообщения или длинные сниппеты), индекс будет расти быстрее, чем таблица.


WITH index_stats AS (
    SELECT
        pg_relation_size('idx_messages_fts') AS current_index_size_bytes,
        (SELECT count(*) FROM messages) AS current_messages
)
SELECT
    current_messages,
    pg_size_pretty(current_index_size_bytes) AS current_index_size,
    pg_size_pretty((current_index_size_bytes::numeric / current_messages)::bigint) AS avg_per_message,
    pg_size_pretty((current_index_size_bytes::numeric / current_messages * 500000)::bigint) AS forecast_500k,
    pg_size_pretty((current_index_size_bytes::numeric / current_messages * 1000000)::bigint) AS forecast_1m,
    pg_size_pretty((current_index_size_bytes::numeric / current_messages * 5000000)::bigint) AS forecast_5m,
    pg_size_pretty((current_index_size_bytes::numeric / current_messages * 10000000)::bigint) AS forecast_10m
FROM index_stats;