-- Read-only deployment inventory. This is not a user-session authorization test.
select jsonb_build_object(
  'tables', (select jsonb_agg(jsonb_build_object('name', c.relname, 'rls', c.relrowsecurity))
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'),
  'buckets', (select jsonb_agg(jsonb_build_object('id', id, 'public', public,
    'limit', file_size_limit, 'mime_types', allowed_mime_types)) from storage.buckets),
  'policies', (select jsonb_agg(jsonb_build_object('schema', schemaname, 'table', tablename,
    'name', policyname, 'roles', roles, 'command', cmd, 'using', qual, 'check', with_check))
    from pg_policies where schemaname in ('public','storage')),
  'grants', (select jsonb_agg(jsonb_build_object('table',table_name,'role',grantee,'privilege',privilege_type))
    from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')),
  'functions', (select jsonb_agg(jsonb_build_object('name', p.proname,
    'security_definer',p.prosecdef,'settings',p.proconfig,'acl',p.proacl))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public')
) as deployment_inventory;
