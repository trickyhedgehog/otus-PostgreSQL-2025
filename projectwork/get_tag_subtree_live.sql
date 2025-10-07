CREATE OR REPLACE FUNCTION get_tag_subtree_live(p_tag_id BIGINT)
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
WITH RECURSIVE
    tag_tree AS (
        -- стартуем с указанного тега
        SELECT t.tag_id,
               t.parent_id,
               t.display_name,
               t.mailbox_type,
               1                      AS level,
               ARRAY [t.display_name] AS path
        FROM tags t
        WHERE t.tag_id = p_tag_id

        UNION ALL

        -- добавляем всех потомков
        SELECT c.tag_id,
               c.parent_id,
               c.display_name,
               c.mailbox_type,
               p.level + 1,
               p.path || c.display_name
        FROM tags c
                 INNER JOIN tag_tree p ON c.parent_id = p.tag_id
    ),
    direct_sizes AS (
        SELECT t.tag_id,
               COALESCE(SUM(
                                s_main.size +
                                COALESCE((SELECT SUM(s_part.size)
                                          FROM parts p
                                                   INNER JOIN s3_objects s_part ON s_part.id = p.object_id
                                          WHERE p.msg_id = m.msg_id), 0)
                        ), 0) AS direct_size
        FROM tags t
                 LEFT JOIN messages m ON m.tag_id = t.tag_id
                 LEFT JOIN s3_objects s_main ON s_main.id = m.object_id
        WHERE t.tag_id IN (SELECT tag_id FROM tag_tree)
        GROUP BY t.tag_id
    ),
    descendants AS (
        SELECT t.tag_id AS root_tag_id,
               t.tag_id AS descendant_tag_id
        FROM tag_tree t

        UNION ALL

        SELECT d.root_tag_id,
               c.tag_id
        FROM descendants d
                 INNER JOIN tag_tree c ON c.parent_id = d.descendant_tag_id
    ),
    totals AS (
        SELECT d.root_tag_id,
               SUM(ds.direct_size) AS total_size
        FROM descendants d
                 INNER JOIN direct_sizes ds ON ds.tag_id = d.descendant_tag_id
        GROUP BY d.root_tag_id
    )
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
FROM get_tag_subtree_live(993646)
ORDER BY level, path;