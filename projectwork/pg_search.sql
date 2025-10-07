CREATE EXTENSION pg_search;
-- https://github.com/paradedb/paradedb/blob/main/benchmarks/README.md

CREATE INDEX ids_messages_snippet_pg_search ON messages
    USING bm25 (msg_id, snippet)
    WITH (
    key_field='msg_id',
    text_fields=
    '{         "snippet": {"tokenizer": {"type": "default", "stemmer": "English"}}, "snippet": {"tokenizer": {"type": "default", "stemmer": "Russian"}}}'
    );


WITH index_stats AS (SELECT pg_relation_size('ids_messages_snippet_pg_search') AS current_index_size_bytes,
                            (SELECT count(*) FROM messages)                    AS current_messages)
SELECT current_messages,
       pg_size_pretty(current_index_size_bytes)                                                  AS current_index_size,
       pg_size_pretty((current_index_size_bytes::numeric / current_messages)::bigint)            AS avg_per_message,
       pg_size_pretty((current_index_size_bytes::numeric / current_messages * 500000)::bigint)   AS forecast_500k,
       pg_size_pretty((current_index_size_bytes::numeric / current_messages * 1000000)::bigint)  AS forecast_1m,
       pg_size_pretty((current_index_size_bytes::numeric / current_messages * 5000000)::bigint)  AS forecast_5m,
       pg_size_pretty((current_index_size_bytes::numeric / current_messages * 10000000)::bigint) AS forecast_10m
FROM index_stats;

SELECT msg_id, snippet
FROM messages
WHERE snippet @@@ 'Зеленский'
  AND snippet @@@ 'leggings';

