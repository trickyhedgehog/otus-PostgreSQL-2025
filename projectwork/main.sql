--CREATE EXTENSION IF NOT EXISTS ltree;
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE TABLE users
(
    user_id    BIGSERIAL PRIMARY KEY,
    email      TEXT        NOT NULL UNIQUE,        -- Основной email пользователя
    login      TEXT        NOT NULL UNIQUE,        -- Логин пользователя в корпоративном каталоге
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- Когда создали
    data       JSONB       NOT NULL                -- документ с данными пользователя - ФИО, должность, что-то ещё
);
-- для выборки по полю users.data
CREATE INDEX idx_users_data_gin ON users USING gin (data);
-- индекс на login, так как по нему будут аутентифицировать пользователей.
CREATE INDEX idx_users_login ON users (login);

SELECT count(*)
FROM users;
-- 100002

-- поддерживается рекурсивная иерархия (каждый тег может иметь родителя);
-- есть привязка к пользователю;
-- в пределах одной папки имена уникальны (и это работает и для корня, без проблем с NULL);
-- гарантируется удобная работа с ON CONFLICT DO NOTHING.
CREATE TYPE mailbox_type_enum AS ENUM ('inbox', 'sent', 'drafts', 'trash', 'junk', 'user');



CREATE TABLE tags
(
    tag_id       BIGSERIAL PRIMARY KEY,
    user_id      BIGINT            NOT NULL REFERENCES users (user_id) ON DELETE CASCADE,
    parent_id    BIGINT REFERENCES tags (tag_id) ON DELETE CASCADE,
    mailbox_type mailbox_type_enum NOT NULL,
    display_name TEXT              NOT NULL,

--     direct_size bigint NOT NULL DEFAULT 0,
--     total_size bigint NOT NULL DEFAULT 0,

    created_at   TIMESTAMPTZ       NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ       NOT NULL DEFAULT now()
);

-- чтобы ускорить tags → users
CREATE INDEX idx_tags_user_id ON tags (user_id);
-- чтобы быстро находить корзинные теги
CREATE INDEX idx_tags_mailbox_type_user_id ON tags (mailbox_type, user_id);

CREATE INDEX idx_tags_parent_id ON tags (parent_id);

-- Поиск по корзине (trashed):
-- Тут идёт переход: messages.tag_id → tags.user_id → tags (user_id, mailbox_type='trash').
-- Чтобы он был быстрым:
CREATE INDEX idx_tags_user_mailbox_type
    ON tags (user_id, mailbox_type);

-- ускоряет выборку всех вложенных папок пользователя;
CREATE INDEX idx_tags_user_parent ON tags (user_id, parent_id);

-- Обеспечиваем уникальность имен тегов в пределах одной папки
-- Трюк: NULL parent_id → заменяем на -1 (виртуальный корень)
CREATE UNIQUE INDEX uq_user_parent_display_name
    ON tags (user_id, COALESCE(parent_id, -1), display_name);

CREATE UNIQUE INDEX uq_user_parent_mailbox_system_type
    ON tags (user_id, COALESCE(parent_id, -1), mailbox_type)
    WHERE mailbox_type != 'user'::mailbox_type_enum;


-- справочник бакетов
CREATE TABLE s3_buckets
(
    id         BIGSERIAL PRIMARY KEY,
    name       TEXT        NOT NULL UNIQUE,
    region     TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- Объекты в S3 (нормализованное хранение)
CREATE TABLE s3_objects
(
    id         BIGSERIAL PRIMARY KEY,
    bucket_id  INT         NOT NULL REFERENCES s3_buckets (id),
    object_key TEXT        NOT NULL,        -- ключ в бакете
    version    TEXT,                        -- versionId (если включено версионирование)
    size       BIGINT      NOT NULL,        -- размер объекта в байтах
    sha256     bytea       NOT NULL,        -- контрольная сумма содержимого
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (bucket_id, object_key, version) -- уникальность ссылки на объект
);

CREATE UNIQUE INDEX idx_s3_objects_sha256_size_more_than_one_mb
    ON s3_objects (sha256, size)  WHERE size > 148576;

-- Критически важный индекс: покрывающий индекс для частого запроса размеров
CREATE INDEX idx_s3_objects_id_size ON s3_objects (id, size);

-- Индекс на (bucket_id, object_key) без version пригодится для случаев, когда нужно искать «последнюю версию»:
CREATE INDEX idx_s3_objects_bucket_key ON s3_objects (bucket_id, object_key);


-- Письма (метаданные)
CREATE TABLE messages
(
    -- глобальный уникальный идентификатор письма (UUIDv6 с датой)
    msg_id    BIGSERIAL PRIMARY KEY,
    -- если сообщение попало в почтовую систему, значит у него должен быть тег
    -- tag_id указывает на текущую папку, где находится письмо или где оно было до удаления в корзину
    -- это поле не изменяется
    tag_id    BIGINT NOT NULL
        REFERENCES tags (tag_id) ON DELETE CASCADE,
    -- ссылка на объект S3 с оригинальным MIME-сообщением
    object_id BIGINT NOT NULL
        REFERENCES s3_objects (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS messages_object_id_idx ON messages (object_id);
CREATE INDEX IF NOT EXISTS messages_tag_id_idx ON messages (tag_id);



CREATE TABLE snippets
(
    msg_id  BIGINT NOT NULL REFERENCES messages (msg_id) ON DELETE CASCADE,
    PRIMARY KEY (msg_id),

    -- текст письма по которому строится полнотекстовый индекс
    snippet TEXT   NOT NULL,

    -- вектор для полнотекстового поиска (russian + english)
    -- генерируется автоматически из поля snippet
    fts     tsvector GENERATED ALWAYS AS (
        to_tsvector('russian', snippet) || to_tsvector('english', snippet)
        ) STORED
) PARTITION BY HASH (msg_id);

-- создаём 10 партиций
do
$$
    begin
        for i in 0..9
            loop
                execute format(
                        'create table snippets_p%s partition of snippets for values with (modulus 10, remainder %s)',
                        i, i
                        );
                execute format(
                        'create index on snippets_p%s using gin (fts)', i
                        );
            end loop;
    end
$$;


-- Журнал переписки
CREATE TABLE correspondence
(
    id      BIGSERIAL PRIMARY KEY,
    time    TIMESTAMPTZ NOT NULL DEFAULT now(), -- время события
    -- ссылка на отправленное сообщение, NULL если получено извне по SMTP, тога recv_id не NULL
    sent_id BIGINT REFERENCES messages (msg_id),
    -- ссылка на входящее сообщение, NULL если отправлено во вне по SMTP, тога sent_id не NULL
    recv_id BIGINT REFERENCES messages (msg_id),
    -- sent_id IS NOT NULL AND recv_id IS NOT NULL: отправлено и получено в системе,
    -- sent_id IS NULL AND recv_id IS NOT NULL: отправлено извне
    -- sent_id IS NOT NULL AND recv_id IS NULL: отправлено во вне
    CHECK ( sent_id IS NOT NULL OR recv_id IS NOT NULL ),
    UNIQUE (sent_id, recv_id)
);
CREATE INDEX correspondence_sent_id_time ON correspondence (sent_id, time);
CREATE INDEX correspondence_recv_id_time ON correspondence (recv_id, time);
CREATE INDEX correspondence_sent_id_recv_id_time ON correspondence (sent_id, recv_id, time);


-- журнал изменения статуса почтовых сообщений
CREATE TABLE messages_status
(
    id     BIGSERIAL PRIMARY KEY,
    msg_id BIGINT      NOT NULL REFERENCES messages (msg_id) ON DELETE CASCADE,
    time   TIMESTAMPTZ NOT NULL DEFAULT now(), -- время события изменения статуса
    -- в какой папке находится сообщение после изменения статуса
    tag_id BIGINT      NOT NULL REFERENCES tags (tag_id) ON DELETE CASCADE,
    status TEXT        NOT NULL
        CHECK (status IN (
                          'created',           -- создан черновик в папке Черновики
                          'sent',              -- письмо отправлено адресатам и находится у отправителя в папке Отправленные
                          'failed',            -- письмо отправлено, но не доставлено
                          'delivered',         -- письмо доставлено получателю или перенаправлено в нужную папку
                          'read',              -- письмо прочитано
                          'moved',             -- пользователь перенёс письмо в другую папку
                          'trashed',           -- пользователь удалил письмо в корзину
                          'deleted',           -- пользователь удалил письмо из корзины
                          'restored'           -- восстановлено из бакапа
            ))
);

-- индекс для ускорения поиска последнего статуса по msg_id
CREATE INDEX idx_messages_status_time_brin ON messages_status USING brin (time);
-- Поле time всегда строго растёт → значит данные вставляются «по времени».
-- Здесь идеален BRIN, потому что:
-- он очень компактный (килобайты вместо гигабайтов);
-- он быстро отфильтрует диапазоны (например, «найти все статусы за сутки»);
-- даже для поиска «последнего статуса» достаточно BRIN + ORDER BY time DESC LIMIT 1 (Postgres быстро найдёт последний блок).

-- Этот индекс нужен для выборки «последнего статуса конкретного письма».
CREATE INDEX idx_messages_status_msg_id_time_desc
    ON messages_status (msg_id, time DESC);


-- MIME-части (структура MIME + связь с объектом в S3)
CREATE TABLE parts
(
    part_id    BIGSERIAL PRIMARY KEY,
    msg_id     BIGINT NOT NULL REFERENCES messages (msg_id) ON DELETE CASCADE,
    -- иерархия multipart
    children   INT[],
    -- порядок внутри multipart
    part_order INT    NOT NULL,
    -- ссылка на объект в S3 (NULL если multipart)
    object_id  BIGINT REFERENCES s3_objects (id),
    -- MIME-заголовки
    headers    JSONB
);
-- Индекс для быстрого доступа к parts по object_id (для JOIN)
CREATE INDEX idx_parts_object_id ON parts (object_id);
-- Индекс для агрегации частей по сообщениям
CREATE INDEX idx_parts_msg_id ON parts (msg_id);
