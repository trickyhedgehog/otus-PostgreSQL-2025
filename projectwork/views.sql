-- Материализовать системные папки в один вью.
-- У каждого пользователя гарантированно не более одной системной папки каждого типа
CREATE OR REPLACE VIEW user_mailboxes AS
SELECT u.user_id,
       COALESCE(MAX(CASE WHEN t.mailbox_type = 'inbox' THEN t.tag_id END), 0)       AS inbox_tag_id,
       COALESCE(MAX(CASE WHEN t.mailbox_type = 'sent' THEN t.tag_id END), 0)        AS sent_tag_id,
       COALESCE(MAX(CASE WHEN t.mailbox_type = 'trash' THEN t.tag_id END), 0)       AS trash_tag_id,
       COALESCE(MAX(CASE WHEN t.mailbox_type = 'junk' THEN t.tag_id END), 0)        AS junk_tag_id,
       COALESCE(MAX(CASE WHEN t.mailbox_type = 'drafts' THEN t.tag_id END), 0)      AS drafts_tag_id,
       COALESCE(MAX(CASE WHEN t.display_name = 'Work' THEN t.tag_id END), 0)        AS work_tag_id,
       COALESCE(MAX(CASE WHEN t.display_name = 'Projects' THEN t.tag_id END), 0)    AS projects_tag_id,
       COALESCE(MAX(CASE WHEN t.display_name = 'Reports' THEN t.tag_id END), 0)     AS reports_tag_id,
       COALESCE(MAX(CASE WHEN t.display_name = 'Personal' THEN t.tag_id END), 0)    AS personal_tag_id,
       COALESCE(MAX(CASE WHEN t.display_name = 'Newsletters' THEN t.tag_id END), 0) AS newsletters_tag_id
FROM users u
         LEFT JOIN tags t
                   ON t.user_id = u.user_id
GROUP BY u.user_id;
----------------------------------------------------------------------------
CREATE OR REPLACE VIEW messages_active_status AS
SELECT DISTINCT ON (ms.msg_id)
    ms.msg_id,
    ms.status,
    ms.tag_id,
    ms.time
FROM messages_status ms
ORDER BY ms.msg_id, ms.time DESC;

SELECT * FROM messages_status WHERE status = 'moved';
----------------------------------------------------------------------------
-- Размер каждого сообщения: сырой объект + все MIME-парты
CREATE OR REPLACE VIEW message_sizes AS
SELECT m.msg_id,
       m.tag_id,
       COALESCE(s_main.size, 0) + COALESCE(SUM(s_part.size), 0) AS msg_size
FROM messages m
         JOIN s3_objects s_main ON s_main.id = m.object_id
         LEFT JOIN parts p ON p.msg_id = m.msg_id
         LEFT JOIN s3_objects s_part ON s_part.id = p.object_id
GROUP BY m.msg_id, m.tag_id, s_main.size;

----------------------------------------------------------------------------
-- Размеры по тегу (только письма напрямую в теге)
CREATE OR REPLACE VIEW tag_direct_size AS
SELECT tag_id,
       SUM(msg_size) AS direct_size
FROM message_sizes
GROUP BY tag_id;

----------------------------------------------------------------------------
WITH RECURSIVE tag_tree AS (
    SELECT t.tag_id,
           t.parent_id,
           t.display_name,
           1 AS level,
           t.mailbox_type,
           ARRAY[t.display_name] AS path
    FROM tags t
    WHERE t.parent_id IS NULL
      AND t.user_id = 123  -- фильтр внутри рекурсии
    UNION ALL
    SELECT c.tag_id,
           c.parent_id,
           c.display_name,
           p.level + 1,
           c.mailbox_type,
           p.path || c.display_name
    FROM tags c
             JOIN tag_tree p ON c.parent_id = p.tag_id
    WHERE c.user_id = 123   -- фильтр внутри рекурсии
)
SELECT *
FROM tag_tree;

----------------------------------------------------------------------------
-- дерево тегов в иерархическом виде для всех пользователей.
CREATE OR REPLACE VIEW tags_hierarchy AS
WITH RECURSIVE tag_tree AS (
    SELECT t.tag_id,
           t.parent_id,
           t.display_name,
           t.mailbox_type,
           1 AS level,
           ARRAY[t.display_name] AS path
    FROM tags t
    WHERE t.parent_id IS NULL

    UNION ALL

    SELECT c.tag_id,
           c.parent_id,
           c.display_name,
           c.mailbox_type,
           p.level + 1,
           p.path || c.display_name
    FROM tags c
             JOIN tag_tree p ON c.parent_id = p.tag_id
)
SELECT t.tag_id,
       t.parent_id,
       t.display_name,
       t.mailbox_type,
       t.level,
       t.path
FROM tag_tree t
         LEFT JOIN tag_tree c ON c.parent_id = t.tag_id
GROUP BY t.tag_id, t.parent_id, t.display_name, t.mailbox_type, t.level, t.path;
----------------------------------------------------------------------------
-- Размер всех тегов с учётом вложенных через path
-- Размеры всех писем в теге и его потомках, используя материализованную иерархию
CREATE OR REPLACE VIEW tag_total_size AS
WITH RECURSIVE tag_descendants AS (
    -- стартуем с каждого тега
    SELECT tag_id AS tag_id,
           tag_id AS descendant_tag_id
    FROM tags_hierarchy

    UNION ALL

    -- рекурсивно добавляем потомков
    SELECT td.tag_id,
           th.tag_id AS descendant_tag_id
    FROM tag_descendants td
             JOIN tags_hierarchy th
                  ON th.parent_id = td.descendant_tag_id
)
SELECT td.tag_id,
       SUM(tds.direct_size) AS total_size
FROM tag_descendants td
         JOIN tag_direct_size tds
              ON tds.tag_id = td.descendant_tag_id
GROUP BY td.tag_id;


