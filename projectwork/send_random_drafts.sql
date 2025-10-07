CREATE OR REPLACE FUNCTION send_random_drafts(p_limit INT)
    RETURNS BIGINT AS $$
DECLARE
    v_msg_id     BIGINT;
    v_user_id    BIGINT;
    v_recipients BIGINT[];
    v_new_ids    BIGINT[];
    v_new_id     BIGINT;
    v_path_str   TEXT;
    v_path       TEXT[];
    v_path_list  TEXT[] := ARRAY[
        'Trash',
        'Junk',
        'Inbox,Work',
        'Inbox,Personal',
        'Inbox,Newsletters',
        'Inbox,Work,Projects',
        'Inbox,Work,Reports'
        ];
    v_target_tag BIGINT;
    v_count      BIGINT := 0;
BEGIN
    -- цикл по случайным черновикам
    FOR v_msg_id, v_user_id IN
        SELECT m.msg_id, t.user_id
        FROM messages m
                 JOIN tags t ON m.tag_id = t.tag_id
                 JOIN user_mailboxes um ON um.user_id = t.user_id
        WHERE m.tag_id = um.drafts_tag_id
        ORDER BY random()
        LIMIT p_limit
        LOOP
            -- случайные 3 получателя (другие пользователи)
            SELECT array_agg(sub.user_id)
            INTO v_recipients
            FROM (
                     SELECT u.user_id
                     FROM users u
                     WHERE u.user_id <> v_user_id
                     ORDER BY random()
                     LIMIT 3
                 ) sub;

            -- вызов функции отправки
            SELECT send_draft(v_msg_id, v_recipients) INTO v_new_ids;

            -- если реально были доставленные сообщения → считаем черновик обработанным
            IF v_new_ids IS NOT NULL AND array_length(v_new_ids,1) > 0 THEN
                v_count := v_count + 1;
            END IF;

            -- переносим каждое полученное сообщение в случайную папку
            FOREACH v_new_id IN ARRAY v_new_ids LOOP
                    v_path_str := v_path_list[(random() * array_length(v_path_list,1) + 1)::int];
                    v_path := string_to_array(v_path_str, ',');

                    SELECT t.tag_id
                    INTO v_target_tag
                    FROM tags t
                    WHERE t.user_id = (
                        SELECT t2.user_id
                        FROM messages m2
                                 JOIN tags t2 ON m2.tag_id = t2.tag_id
                        WHERE m2.msg_id = v_new_id
                    )
                      AND t.display_name = v_path[array_length(v_path,1)];

                    IF v_target_tag IS NOT NULL THEN
                        PERFORM move_message(v_new_id, v_target_tag);
                    END IF;
                END LOOP;
        END LOOP;

    RETURN v_count;
END;
$$ LANGUAGE plpgsql;



SELECT send_random_drafts(1000);