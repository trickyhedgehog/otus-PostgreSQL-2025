CREATE OR REPLACE FUNCTION get_tags_hierarchy_live_json(p_user_id BIGINT)
    RETURNS jsonb
    LANGUAGE plpgsql AS
$$
DECLARE
    rec RECORD;

    -- map: tag_id(text) -> jsonb node
    nodes_map jsonb := '{}'::jsonb;

    -- map: parent_tag_id(text) -> jsonb array of children
    children_map jsonb := '{}'::jsonb;

    -- helper values
    node jsonb;
    existing_children jsonb;
    roots jsonb := '[]'::jsonb;
BEGIN
    /*
      1) Проходим все строки get_tags_hierarchy_live в порядке level DESC (листья сначала).
      2) Для каждого узла достаём уже накопленных детей из children_map (если есть),
         строим node JSON и сохраняем в nodes_map[tag_id].
      3) Если у узла есть parent_id — добавляем node в children_map[parent_id] (накопляем).
    */

    FOR rec IN
        SELECT * FROM get_tags_hierarchy_live(p_user_id)
        ORDER BY level DESC, path DESC
        LOOP
            -- дети, которые уже накоплены для этого тега (если нет — пустой массив)
            existing_children := COALESCE(children_map -> rec.tag_id::text, '[]'::jsonb);

            -- строим узел; используем to_jsonb для path чтобы корректно вложить array
            node := jsonb_build_object(
                    'tag_id', rec.tag_id,
                    'display_name', rec.display_name,
                    'mailbox_type', rec.mailbox_type,
                    'level', rec.level,
                    'path', to_jsonb(rec.path),
                    'direct_size', COALESCE(rec.direct_size, 0),
                    'total_size', COALESCE(rec.total_size, 0),
                    'children', existing_children
                    );

            -- сохраняем узел в map по ключу tag_id
            nodes_map := nodes_map || jsonb_build_object(rec.tag_id::text, node);

            -- если есть родитель — прикрепляем этот узел к массиву детей родителя (накопление)
            IF rec.parent_id IS NOT NULL THEN
                existing_children := COALESCE(children_map -> rec.parent_id::text, '[]'::jsonb);
                children_map := children_map || jsonb_build_object(rec.parent_id::text, existing_children || jsonb_build_array(node));
            END IF;
        END LOOP;

    /*
      4) Теперь собираем корневые узлы в нужном порядке (order by level, path ASC)
         и формируем итоговый JSON-массив.
    */
    FOR rec IN
        SELECT tag_id
        FROM get_tags_hierarchy_live(p_user_id)
        WHERE parent_id IS NULL
        ORDER BY level, path
        LOOP
            -- Возьмём итоговый узел из nodes_map (должен быть)
            IF nodes_map ? rec.tag_id::text THEN
                roots := roots || jsonb_build_array(nodes_map -> rec.tag_id::text);
            END IF;
        END LOOP;

    RETURN roots;
END;
$$;
-- используем ORDER BY level DESC при проходе, чтобы сначала обработать листья — тогда, когда мы доходим до родителя, children_map уже содержит готовые JSON-массивы детей.
-- nodes_map — jsonb-объект, ключи — tag_id как текст; значения — JSON-объекты узлов. Это удобный in-memory «хэш».
-- В финале мы формируем roots в порядке level, path (как в get_tags_hierarchy_live), чтобы сохранить читаемый порядок папок.
-- Функция возвращает jsonb — массив корневых узлов. Если нужно json — можно привести.
-- делаем один вызов get_tags_hierarchy_live(p_user_id) (который уже оптимизирован), затем простую in-memory обработку; это эффективно даже для сотен/тысяч узлов.

SELECT jsonb_pretty(get_tags_hierarchy_live_json(99366));