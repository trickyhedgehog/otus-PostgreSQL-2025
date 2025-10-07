----------------------------------------------------------------------------
-- Автообновление updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_set_updated_at
    BEFORE UPDATE
    ON tags
    FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
----------------------------------------------------------------------------