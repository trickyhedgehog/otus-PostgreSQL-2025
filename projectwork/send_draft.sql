CREATE OR REPLACE FUNCTION send_draft(
    p_msg_id BIGINT,         -- id черновика
    p_recipient_ids BIGINT[] -- массив user_id получателей (только внутренние!)
)
    RETURNS BIGINT[] -- массив msg_id доставленных сообщений
    LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id          BIGINT;
    v_sender_email     TEXT;
    v_sender_domain    TEXT;
    v_drafts_tag       BIGINT;
    v_recipient_id     BIGINT;
    v_recipient_email  TEXT;
    v_recipient_emails TEXT[];
    v_sent_tag         BIGINT;
    v_inbox_tag        BIGINT;
    v_new_msg_id       BIGINT;
    v_delivered_ids    BIGINT[] := '{}';
    v_now              TIMESTAMPTZ := now();
    v_message_id       TEXT;
    v_snippet          TEXT;
BEGIN
    -- 1. Определяем владельца, email и tag_id исходного сообщения
    SELECT t.user_id, u.email, m.tag_id
    INTO v_user_id, v_sender_email, v_drafts_tag
    FROM messages m
             JOIN tags t ON m.tag_id = t.tag_id
             JOIN users u ON t.user_id = u.user_id
    WHERE m.msg_id = p_msg_id;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Не удалось найти владельца сообщения %', p_msg_id;
    END IF;

    -- 2. Проверяем, что сообщение действительно в Drafts
    PERFORM 1
    FROM user_mailboxes um
    WHERE um.user_id = v_user_id
      AND um.drafts_tag_id = v_drafts_tag;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Сообщение % не находится в папке Черновики пользователя %', p_msg_id, v_user_id;
    END IF;

    -- выделяем домен из email отправителя
    v_sender_domain := split_part(v_sender_email, '@', 2);

    -- 3. Находим "Sent" для отправителя
    SELECT sent_tag_id
    INTO v_sent_tag
    FROM user_mailboxes
    WHERE user_id = v_user_id;

    IF v_sent_tag IS NULL THEN
        RAISE EXCEPTION 'У пользователя % нет папки Sent', v_user_id;
    END IF;

    -- 4. Получаем email всех получателей
    SELECT array_agg(email ORDER BY user_id)
    INTO v_recipient_emails
    FROM users
    WHERE user_id = ANY(p_recipient_ids);

    IF v_recipient_emails IS NULL THEN
        RAISE EXCEPTION 'Не удалось найти email получателей %', p_recipient_ids;
    END IF;

    -- 5. Генерируем RFC-совместимый Message-ID
    v_message_id := '<msg-' || p_msg_id || '-' || extract(epoch from v_now)::bigint || '@' || v_sender_domain || '>';

    -- 6. Переносим черновик в "Sent"
    UPDATE messages
    SET tag_id = v_sent_tag
    WHERE msg_id = p_msg_id;

    -- 7. Логируем статус "sent"
    INSERT INTO messages_status (msg_id, tag_id, status)
    VALUES (p_msg_id, v_sent_tag, 'sent');

    -- 8. Дописываем заголовки в main part исходящего письма
    UPDATE parts
    SET headers = headers
        || jsonb_build_object(
                          'From', v_sender_email,
                          'To', array_to_string(v_recipient_emails, ', '),
                          'Date', to_char(v_now, 'Dy, DD Mon YYYY HH24:MI:SS TZ'),
                          'Message-ID', v_message_id,
                          'X-Mailer', 'UCS-Mail'
           )
    WHERE msg_id = p_msg_id
      AND part_order = 0;

    -- 9. Достаём snippet для копирования
    SELECT snippet INTO v_snippet
    FROM snippets
    WHERE msg_id = p_msg_id;

    IF v_snippet IS NULL THEN
        RAISE EXCEPTION 'У черновика % нет snippet', p_msg_id;
    END IF;

    -- 10. Создаём входящие для получателей
    FOREACH v_recipient_id IN ARRAY p_recipient_ids LOOP
            -- находим email и Inbox получателя
            SELECT u.email, um.inbox_tag_id
            INTO v_recipient_email, v_inbox_tag
            FROM users u
                     JOIN user_mailboxes um ON um.user_id = u.user_id
            WHERE u.user_id = v_recipient_id;

            IF v_inbox_tag IS NULL THEN
                RAISE EXCEPTION 'У получателя % нет Inbox', v_recipient_id;
            END IF;

            -- создаём запись в messages
            INSERT INTO messages (tag_id, object_id)
            SELECT v_inbox_tag, object_id
            FROM messages
            WHERE msg_id = p_msg_id
            RETURNING msg_id INTO v_new_msg_id;

            -- создаём snippet для нового сообщения
            INSERT INTO snippets (msg_id, snippet)
            VALUES (v_new_msg_id, v_snippet);

            -- добавляем в массив доставленных
            v_delivered_ids := array_append(v_delivered_ids, v_new_msg_id);

            -- логируем доставку
            INSERT INTO messages_status (msg_id, tag_id, status)
            VALUES (v_new_msg_id, v_inbox_tag, 'delivered');

            -- correspondence: связь "отправлено → доставлено"
            INSERT INTO correspondence (sent_id, recv_id)
            VALUES (p_msg_id, v_new_msg_id);

            -- заголовки в main part входящего письма
            UPDATE parts
            SET headers = headers
                || jsonb_build_object(
                                  'From', v_sender_email,
                                  'To', v_recipient_email,
                                  'Delivered-To', v_recipient_email,
                                  'Date', to_char(v_now, 'Dy, DD Mon YYYY HH24:MI:SS TZ'),
                                  'Message-ID', v_message_id
                   )
            WHERE msg_id = v_new_msg_id
              AND part_order = 0;
        END LOOP;

    RETURN v_delivered_ids;
END;
$$;
