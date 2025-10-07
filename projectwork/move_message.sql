CREATE OR REPLACE FUNCTION move_message(
    p_msg_id BIGINT,
    p_new_tag_id BIGINT
) RETURNS VOID AS $$
DECLARE
    v_old_tag BIGINT;
    v_user_id BIGINT;
    v_new_user_id BIGINT;
BEGIN
    -- получаем текущий tag_id и владельца
    SELECT m.tag_id, t.user_id
    INTO v_old_tag, v_user_id
    FROM messages m
             JOIN tags t ON m.tag_id = t.tag_id
    WHERE m.msg_id = p_msg_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Message % not found', p_msg_id;
    END IF;

    -- проверяем, что новый тег принадлежит тому же пользователю
    SELECT t.user_id
    INTO v_new_user_id
    FROM tags t
    WHERE t.tag_id = p_new_tag_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Tag % not found', p_new_tag_id;
    END IF;

    IF v_new_user_id <> v_user_id THEN
        RAISE EXCEPTION 'Tag % does not belong to the same user as message %',
            p_new_tag_id, p_msg_id;
    END IF;

    -- обновляем сообщение
    UPDATE messages
    SET tag_id = p_new_tag_id
    WHERE msg_id = p_msg_id;

    -- логируем событие
    INSERT INTO messages_status (msg_id, tag_id, time, status)
    VALUES (p_msg_id, p_new_tag_id, now() + interval '1 second', 'moved');

END;
$$ LANGUAGE plpgsql;