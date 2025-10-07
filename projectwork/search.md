# Поиск

```sql
ANALYZE snippets;
EXPLAIN ANALYSE SELECT msg_id, snippet
FROM snippets
WHERE fts @@ plainto_tsquery('russian', 'Зеленский')
  AND fts @@ plainto_tsquery('english', 'leggings');
```
```text
+---------------------------------------------------------------------------------------------------------------------------------------+
|QUERY PLAN                                                                                                                             |
+---------------------------------------------------------------------------------------------------------------------------------------+
|Append  (cost=31.08..5514.29 rows=1846 width=1073) (actual time=0.236..12.840 rows=1784 loops=1)                                       |
|  ->  Bitmap Heap Scan on snippets_p0 snippets_1  (cost=31.08..569.46 rows=193 width=1060) (actual time=0.236..1.391 rows=195 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=186                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p0_fts_idx  (cost=0.00..31.03 rows=193 width=0) (actual time=0.201..0.201 rows=195 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p1 snippets_2  (cost=31.04..557.69 rows=186 width=1076) (actual time=0.256..1.221 rows=174 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=169                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p1_fts_idx  (cost=0.00..31.00 rows=186 width=0) (actual time=0.222..0.222 rows=174 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p2 snippets_3  (cost=31.12..586.15 rows=202 width=1084) (actual time=0.242..1.340 rows=199 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=192                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p2_fts_idx  (cost=0.00..31.07 rows=202 width=0) (actual time=0.204..0.204 rows=199 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p3 snippets_4  (cost=30.96..519.64 rows=171 width=1071) (actual time=0.267..1.276 rows=157 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=146                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p3_fts_idx  (cost=0.00..30.92 rows=171 width=0) (actual time=0.228..0.228 rows=157 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p4 snippets_5  (cost=30.97..525.57 rows=173 width=1074) (actual time=0.275..1.164 rows=176 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=165                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p4_fts_idx  (cost=0.00..30.93 rows=173 width=0) (actual time=0.236..0.236 rows=176 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p5 snippets_6  (cost=31.05..553.77 rows=187 width=1071) (actual time=0.206..1.045 rows=153 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=151                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p5_fts_idx  (cost=0.00..31.00 rows=187 width=0) (actual time=0.175..0.175 rows=153 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p6 snippets_7  (cost=31.12..584.83 rows=200 width=1082) (actual time=0.347..1.461 rows=205 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=194                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p6_fts_idx  (cost=0.00..31.07 rows=200 width=0) (actual time=0.309..0.309 rows=205 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p7 snippets_8  (cost=30.96..519.64 rows=171 width=1074) (actual time=0.287..1.186 rows=169 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=159                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p7_fts_idx  (cost=0.00..30.92 rows=171 width=0) (actual time=0.215..0.215 rows=169 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p8 snippets_9  (cost=31.00..535.40 rows=178 width=1071) (actual time=0.248..1.380 rows=175 loops=1) |
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=165                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p8_fts_idx  (cost=0.00..30.96 rows=178 width=0) (actual time=0.207..0.208 rows=175 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|  ->  Bitmap Heap Scan on snippets_p9 snippets_10  (cost=31.03..552.91 rows=185 width=1065) (actual time=0.258..1.216 rows=181 loops=1)|
|        Recheck Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                                |
|        Heap Blocks: exact=169                                                                                                         |
|        ->  Bitmap Index Scan on snippets_p9_fts_idx  (cost=0.00..30.99 rows=185 width=0) (actual time=0.225..0.225 rows=181 loops=1)  |
|              Index Cond: ((fts @@ '''Зеленск'''::tsquery) AND (fts @@ '''leg'''::tsquery))                                            |
|Planning Time: 11.670 ms                                                                                                               |
|Execution Time: 13.186 ms                                                                                                              |
+---------------------------------------------------------------------------------------------------------------------------------------+
```

- Использовано hash-партиционирование на 10 частей
- Планировщик делает Append по всем партициям (snippets_p0 … snippets_p9),
- В каждой — Bitmap Index Scan по GIN-индексу на fts,
- Дальше Bitmap Heap Scan для вытаскивания строк.
- Execution Time: 13 ms вместо сотен миллисекунд/секунд, которые я видел при RANGE-партиционировании без актуальной статистики.
- Каждая партиция даёт кусочек результата, и всё это складывается.

## 🔑 Важные выводы:

- HASH-партиционирование по msg_id работает ожидаемо: Postgres вынужден пройти все 10 партиций, потому что условие фильтрации по fts, а не по msg_id.
- Если бы условие было вида msg_id = 12345, то отработала бы только одна партиция (Postgres вычисляет hash(12345) % 10).
- FTS-запросы прекрасно используют GIN-индексы внутри партиций.
- ANALYZE реально критичен для таких запросов — до него планировщик может переоценивать селективность и сканить последовательно.