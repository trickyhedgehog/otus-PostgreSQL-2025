

CREATE OR REPLACE FUNCTION move_snippets_from_default()
    RETURNS void
    LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    part_name TEXT;
    temp_name TEXT;
    part_from TIMESTAMPTZ;
    part_to   TIMESTAMPTZ;
    cnt INT;
BEGIN
    FOR rec IN
        SELECT DISTINCT date_trunc('month', time) AS month_start
        FROM snippets_default
        ORDER BY month_start
        LOOP
            part_from := rec.month_start;
            part_to   := part_from + INTERVAL '1 month';
            part_name := format('snippets_%s_%02s',
                                EXTRACT(YEAR FROM part_from)::INT,
                                EXTRACT(MONTH FROM part_from)::INT);
            temp_name := part_name || '_temp';

            -- Считаем строки
            EXECUTE format(
                    'SELECT count(*) FROM snippets_default WHERE time >= %L AND time < %L',
                    part_from, part_to
                    ) INTO cnt;

            IF cnt > 0 THEN
                RAISE NOTICE 'Обработка %: найдено % строк', part_name, cnt;

                -- 1. Создаём временную таблицу
                EXECUTE format(
                        'CREATE TABLE IF NOT EXISTS %I (LIKE snippets INCLUDING ALL)',
                        temp_name
                        );

                -- 2. Перемещаем данные (без fts!) во временную
                EXECUTE format(
                        'INSERT INTO %I (msg_id, snippet, time) ' ||
                        'SELECT msg_id, snippet, time FROM snippets_default ' ||
                        'WHERE time >= %L AND time < %L',
                        temp_name, part_from, part_to
                        );
                GET DIAGNOSTICS cnt = ROW_COUNT;
                RAISE NOTICE 'Перемещено % строк во временную таблицу %', cnt, temp_name;

                -- 3. Удаляем из default
                EXECUTE format(
                        'DELETE FROM snippets_default WHERE time >= %L AND time < %L',
                        part_from, part_to
                        );
                RAISE NOTICE 'Удалено % строк из snippets_default', cnt;

                -- 4. Создаём целевую партицию
                BEGIN
                    EXECUTE format(
                            'CREATE TABLE %I PARTITION OF snippets FOR VALUES FROM (%L) TO (%L)',
                            part_name, part_from, part_to
                            );
                    RAISE NOTICE 'Создана партиция %', part_name;
                EXCEPTION WHEN duplicate_table THEN
                    RAISE NOTICE 'Партиция % уже существует', part_name;
                END;

                -- 5. Перемещаем из временной в партицию (без fts!)
                EXECUTE format(
                        'INSERT INTO %I (msg_id, snippet, time) ' ||
                        'SELECT msg_id, snippet, time FROM %I',
                        part_name, temp_name
                        );
                GET DIAGNOSTICS cnt = ROW_COUNT;
                RAISE NOTICE 'Перемещено % строк в партицию %', cnt, part_name;

                -- 6. Удаляем временную таблицу
                EXECUTE format('DROP TABLE %I', temp_name);
            END IF;
        END LOOP;
END;
$$;


SELECT move_snippets_from_default();