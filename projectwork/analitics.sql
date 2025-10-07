-- Количество пользователей, зарегистрированных за последние N дней:
SELECT date_trunc('day', created_at) AS day, COUNT(*) AS users_count
FROM users
WHERE created_at >= now() - interval '30 days'
GROUP BY day
ORDER BY day;

-- Количество тегов и системных папок на пользователя:
SELECT u.user_id,
       u.login,
       COUNT(t.tag_id)                                      AS total_tags,
       COUNT(CASE WHEN t.mailbox_type != 'user' THEN 1 END) AS system_folders
FROM users u
         LEFT JOIN tags t ON t.user_id = u.user_id
GROUP BY u.user_id, u.login;

-- Чтобы понять из какого тега было перемещено сообщение, нужно:
-- взять все записи со статусом moved из messages_status (они содержат новый tag_id, куда сообщение попало),
-- найти предыдущий статус того же сообщения, который был перед этим moved,
-- взять его tag_id → это и будет «откуда».
WITH status_with_prev AS (SELECT ms.msg_id,
                                 ms.id,
                                 ms.tag_id                                                     AS new_tag_id,
                                 LAG(ms.tag_id) OVER (PARTITION BY ms.msg_id ORDER BY ms.time) AS old_tag_id,
                                 ms.status,
                                 ms.time
                          FROM messages_status ms)
SELECT swp.msg_id,
       swp.time,
       swp.old_tag_id     AS tag_id_prev,
       t_old.display_name AS from_folder,
       t_new.display_name AS to_folder,
       u.email            AS user_email
FROM status_with_prev swp
         LEFT JOIN tags t_old ON t_old.tag_id = swp.old_tag_id
         LEFT JOIN tags t_new ON t_new.tag_id = swp.new_tag_id
         LEFT JOIN users u ON u.user_id = t_new.user_id -- сообщение перемещается в этот тег
WHERE swp.status = 'moved'
ORDER BY swp.time DESC;


-- Количество писем по статусу для каждого пользователя:
SELECT u.email  AS email,
       ms.status,
       COUNT(*) AS msg_count
FROM messages_status ms
         JOIN messages m ON ms.msg_id = m.msg_id
         JOIN tags t ON m.tag_id = t.tag_id
         JOIN users u USING (user_id)
WHERE ms.status != 'created'
GROUP BY u.email, ms.status
ORDER BY u.email, ms.status;

-- Количество Исходящих писем (sent) для каждого пользователя:
SELECT u.user_id, u.login, COUNT(m.msg_id) AS sent_count
FROM messages m
         JOIN tags t ON t.tag_id = m.tag_id AND t.mailbox_type = 'sent'
         JOIN users u ON u.user_id = t.user_id
GROUP BY u.user_id, u.login;

-- количество писем на тег:
SELECT t.tag_id, t.display_name, COUNT(m.msg_id) AS messages_count
FROM tags t
         LEFT JOIN messages m ON m.tag_id = t.tag_id
GROUP BY t.tag_id, t.display_name
ORDER BY messages_count DESC;


-- Общий размер хранилища по бакетам:
SELECT b.name AS bucket_name, COUNT(o.id) AS object_count, SUM(o.size) AS total_size_bytes
FROM s3_buckets b
         JOIN s3_objects o ON o.bucket_id = b.id
GROUP BY b.name
ORDER BY total_size_bytes DESC;

-- Количество MIME-частей на сообщение:
SELECT msg_id, COUNT(*) AS parts_count
FROM parts
GROUP BY msg_id
ORDER BY parts_count DESC
LIMIT 20;

-- Сколько сообщений имеют вложенные multipart-части:
SELECT COUNT(DISTINCT msg_id) AS messages_with_multipart
FROM parts
WHERE array_length(children, 1) > 0;

-- Количество полученных и отправленных писем по дням:
SELECT date_trunc('day', received_at)                          AS day,
       COUNT(*) FILTER (WHERE status IN ('delivered', 'read')) AS received_count,
       COUNT(*) FILTER (WHERE status IN ('sent', 'failed'))    AS sent_count
FROM messages
GROUP BY day
ORDER BY day;

-- Количество новых пользователей и сообщений в день:
SELECT date_trunc('day', u.created_at) AS day,
       COUNT(DISTINCT u.user_id)       AS new_users,
       COUNT(DISTINCT m.msg_id)        AS new_messages
FROM users u
         LEFT JOIN tags t ON t.user_id = u.user_id
         LEFT JOIN messages m ON m.tag_id = t.tag_id
GROUP BY day
ORDER BY day;

-- Общая сумма всех сообщений пользователя
SELECT u.user_id, u.login, SUM(ms.msg_size) AS total_user_size
FROM message_sizes ms
         JOIN tags t ON t.tag_id = ms.tag_id
         JOIN users u ON u.user_id = t.user_id
GROUP BY u.user_id, u.login
ORDER BY total_user_size DESC;


-- Топ пользователей по объему почты
SELECT u.user_id,
       u.email,
       SUM(COALESCE(so.size, 0)) as total_storage_bytes,
       COUNT(DISTINCT m.msg_id)  as total_messages,
       COUNT(DISTINCT t.tag_id)  as total_folders
FROM users u
         LEFT JOIN tags t ON t.user_id = u.user_id
         LEFT JOIN messages m ON m.tag_id = t.tag_id
         LEFT JOIN s3_objects so ON so.id = m.object_id
GROUP BY u.user_id, u.email
ORDER BY total_storage_bytes DESC
LIMIT 10;

-- Дубликаты файлов в S3 (экономия за счет дедупликации)
SELECT so.sha256,
       so.size,
       COUNT(DISTINCT so.id)                 as total_duplicates,
       COUNT(DISTINCT m.msg_id)              as linked_messages,
       COUNT(DISTINCT so.bucket_id)          as buckets_used,
       so.size * (COUNT(DISTINCT so.id) - 1) as potential_savings_bytes
FROM s3_objects so
         LEFT JOIN messages m ON m.object_id = so.id
WHERE so.sha256 IS NOT NULL
  AND so.size > 10240 -- только значимые файлы > 10KB
GROUP BY so.sha256, so.size
HAVING COUNT(DISTINCT so.id) > 1
ORDER BY potential_savings_bytes DESC
LIMIT 15;

-- Размер всех PDF частей across всех сообщений
SELECT COUNT(DISTINCT p.part_id)    as total_pdf_parts,
       COUNT(DISTINCT p.msg_id)     as messages_with_pdf,
       -- SUM(so.size) as total_pdf_size_bytes,
       PG_SIZE_PRETTY(SUM(so.size)) as total_pdf_size_pretty,
       PG_SIZE_PRETTY(AVG(so.size)) as avg_pdf_size_bytes,
       PG_SIZE_PRETTY(MAX(so.size)) as max_pdf_size_bytes
FROM parts p
         JOIN s3_objects so ON so.id = p.object_id
WHERE p.object_id IS NOT NULL
  AND (p.headers ->> 'Content-Type' ILIKE '%pdf%'
    OR p.headers ->> 'Content-Disposition' ILIKE '%pdf%');




