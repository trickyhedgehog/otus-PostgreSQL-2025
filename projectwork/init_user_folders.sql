-- init_user_folders - идемпотентная
-- то есть при повторном вызове не создавались дубли. Для этого будем использовать
-- INSERT ... ON CONFLICT DO NOTHING и/или проверки через SELECT ... INTO.
CREATE OR REPLACE FUNCTION init_user_folders(p_user_id BIGINT)
    RETURNS void
    LANGUAGE plpgsql AS
$$
DECLARE
    inbox_id BIGINT;
    work_id  BIGINT;
BEGIN
    -- базовые корневые папки
    INSERT INTO tags (user_id, parent_id, display_name, mailbox_type)
    VALUES (p_user_id, NULL, 'Inbox', 'inbox'),
           (p_user_id, NULL, 'Sent', 'sent'),
           (p_user_id, NULL, 'Drafts', 'drafts'),
           (p_user_id, NULL, 'Trash', 'trash'),
           (p_user_id, NULL, 'Junk', 'junk')
    ON CONFLICT (user_id, COALESCE(parent_id, -1), display_name) DO NOTHING;

    -- получаем id Inbox
    SELECT tag_id
    INTO inbox_id
    FROM tags
    WHERE user_id = p_user_id
      AND parent_id IS NULL
      AND display_name = 'Inbox'
    LIMIT 1;

    -- подпапки внутри Inbox
    INSERT INTO tags (user_id, parent_id, display_name, mailbox_type)
    VALUES (p_user_id, inbox_id, 'Work', 'user'),
           (p_user_id, inbox_id, 'Personal', 'user'),
           (p_user_id, inbox_id, 'Newsletters', 'user')
    ON CONFLICT (user_id, COALESCE(parent_id, -1), display_name) DO NOTHING;

    -- получаем id Work
    SELECT tag_id
    INTO work_id
    FROM tags
    WHERE user_id = p_user_id
      AND parent_id = inbox_id
      AND display_name = 'Work'
    LIMIT 1;

    -- вложенные папки в Work
    INSERT INTO tags (user_id, parent_id, display_name, mailbox_type)
    VALUES (p_user_id, work_id, 'Projects', 'user'),
           (p_user_id, work_id, 'Reports', 'user')
    ON CONFLICT (user_id, COALESCE(parent_id, -1), display_name) DO NOTHING;
END;
$$;

SELECT init_user_folders(user_id)
FROM users;

-- При создании новой записи в users автоматически создаём стандартные папки (Inbox, Sent, Drafts, Trash, и вложенные).

-- 1. Триггерная функция
CREATE OR REPLACE FUNCTION trg_init_folders()
    RETURNS trigger
    LANGUAGE plpgsql AS
$$
BEGIN
    -- вызываем инициализацию для нового пользователя
    PERFORM init_user_folders(NEW.user_id);
    RETURN NEW;
END;
$$;

-- 2. Триггер на вставку
CREATE OR REPLACE TRIGGER trg_users_init_folders
    AFTER INSERT
    ON users
    FOR EACH ROW
EXECUTE FUNCTION trg_init_folders();