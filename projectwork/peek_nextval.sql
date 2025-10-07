CREATE OR REPLACE FUNCTION peek_nextval(seq_name text)
    RETURNS bigint
    LANGUAGE plpgsql
AS
$$
DECLARE
    relid    oid;
    last     bigint;
    inc      bigint;
    startval bigint;
    result   bigint;
BEGIN
    -- найдём oid последовательности
    SELECT c.oid
    INTO relid
    FROM pg_class c
             JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'S'
      AND (c.relname = seq_name OR n.nspname || '.' || c.relname = seq_name);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sequence "%" not found', seq_name;
    END IF;

    -- достаём параметры из pg_sequence
    SELECT pg_sequence_last_value(relid::regclass),
           s.seqincrement,
           s.seqstart
    INTO last, inc, startval
    FROM pg_sequence s
    WHERE s.seqrelid = relid;

    -- вычисляем следующее значение
    IF last IS NULL THEN
        result := startval; -- ещё не вызывали nextval()
    ELSE
        result := last + inc;
    END IF;

    RETURN result;
END;
$$;

SELECT peek_nextval('s3_objects_id_seq');