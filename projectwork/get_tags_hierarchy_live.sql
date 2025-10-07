CREATE OR REPLACE FUNCTION get_tags_hierarchy_live(p_user_id BIGINT)
    RETURNS TABLE
            (
                tag_id       BIGINT,
                parent_id    BIGINT,
                display_name TEXT,
                mailbox_type TEXT,
                level        INT,
                path         TEXT[],
                direct_size  BIGINT,
                total_size   BIGINT
            )
AS
$$
/*
    Функция возвращает иерархию тегов (папок) пользователя вместе с размерами:
    - direct_size: общий размер всех сообщений, непосредственно лежащих в этом теге.
    - total_size:  общий размер сообщений во всём поддереве (включая дочерние теги).

    Особенность: размеры считаются "на лету" через таблицу s3_objects (без использования
    закешированных колонок tags.size и messages.size).

    Внутри используется несколько CTE:
      1) tag_tree     – рекурсивно строим дерево тегов для пользователя.
      2) direct_sizes – считаем размеры сообщений в каждом теге (direct_size).
      3) descendants  – строим пары (root_tag_id, descendant_tag_id), чтобы найти всех потомков.
      4) totals       – суммируем direct_size потомков для каждого root_tag_id → получаем total_size.

    Итоговый SELECT склеивает всё воедино.
*/
WITH RECURSIVE
    -- 1. Рекурсивно строим дерево тегов для пользователя
    tag_tree AS (
        -- корневые теги (без parent_id)
        SELECT t.tag_id,
               t.parent_id,
               t.display_name,
               t.mailbox_type,
               1                      AS level,
               ARRAY [t.display_name] AS path
        FROM tags t
        WHERE t.user_id = p_user_id
          AND t.parent_id IS NULL

        UNION ALL

        -- дочерние теги: рекурсивно углубляемся вниз
        SELECT c.tag_id,
               c.parent_id,
               c.display_name,
               c.mailbox_type,
               p.level + 1,
               p.path || c.display_name
        FROM tags c
                 INNER JOIN tag_tree p ON c.parent_id = p.tag_id
        WHERE c.user_id = p_user_id
    ),

    -- 2. Считаем direct_size для каждого тега: размеры всех сообщений, которые лежат прямо в этом теге
    direct_sizes AS (
        SELECT t.tag_id,
               COALESCE(SUM(
                            -- размер основного объекта сообщения
                                s_main.size
                                    +
                                    -- плюс размер всех частей (attachments)
                                COALESCE((
                                             SELECT SUM(s_part.size)
                                             FROM parts p
                                                      INNER JOIN s3_objects s_part ON s_part.id = p.object_id
                                             WHERE p.msg_id = m.msg_id
                                         ), 0)
                        ), 0) AS direct_size
        FROM tags t
                 LEFT JOIN messages m ON m.tag_id = t.tag_id
                 LEFT JOIN s3_objects s_main ON s_main.id = m.object_id
        WHERE t.user_id = p_user_id
        GROUP BY t.tag_id
    ),

    -- 3. Строим "список потомков" для каждого тега (root_tag_id → descendant_tag_id)
    descendants AS (
        -- каждый тег является потомком сам себе
        SELECT t.tag_id AS root_tag_id,
               t.tag_id AS descendant_tag_id
        FROM tag_tree t

        UNION ALL

        -- добавляем дочерние связи
        SELECT d.root_tag_id,
               c.tag_id
        FROM descendants d
                 INNER JOIN tag_tree c ON c.parent_id = d.descendant_tag_id
    ),

    -- 4. Считаем total_size для каждого root_tag_id (сумма direct_size всех его потомков)
    totals AS (
        SELECT d.root_tag_id,
               SUM(ds.direct_size) AS total_size
        FROM descendants d
                 INNER JOIN direct_sizes ds ON ds.tag_id = d.descendant_tag_id
        GROUP BY d.root_tag_id
    )

-- 5. Финальный результат: объединяем дерево + размеры
SELECT tt.tag_id,
       tt.parent_id,
       tt.display_name,
       tt.mailbox_type,
       tt.level,
       tt.path,
       COALESCE(ds.direct_size, 0) AS direct_size,
       COALESCE(tot.total_size, 0) AS total_size
FROM tag_tree tt
         LEFT JOIN direct_sizes ds ON ds.tag_id = tt.tag_id
         LEFT JOIN totals tot ON tot.root_tag_id = tt.tag_id
ORDER BY tt.level, tt.path;
$$ LANGUAGE sql STABLE;

SELECT *
FROM get_tags_hierarchy_live(71405)
ORDER BY level, path;
-- execution: 9 ms





