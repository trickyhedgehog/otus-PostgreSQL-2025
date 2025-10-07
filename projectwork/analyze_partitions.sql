create or replace function analyze_partitions(parent_table text)
    returns void language plpgsql as $$
declare
    r record;
begin
    -- сначала сам родитель
    execute format('ANALYZE %I;', parent_table);

    -- теперь все партиции
    for r in
        select inhrelid::regclass as part
        from pg_inherits
        where inhparent = parent_table::regclass
        loop
            raise notice 'ANALYZE %', r.part;
            execute format('ANALYZE %s;', r.part);
        end loop;
end$$;

select analyze_partitions('snippets');