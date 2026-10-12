-- Verification queries. Run through the Supabase SQL editor or `psql`.
--
-- These check the things that are easy to get wrong and hard to notice: RLS
-- actually enabled, the tables created, and the indexes in place.

-- 1. All tables should exist.
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;

-- 2. RLS must be ENABLED on every one. "NO" here is a security hole.
select c.relname as table_name,
       c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname;

-- 3. Policy count per table. A table with policies but RLS off is a silent
--    hole: the policies exist but are never consulted.
select tablename, count(*) as policies
from pg_policies
where schemaname = 'public'
group by tablename
order by tablename;

-- 4. The role check constraint must reject unknown roles.
select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.profiles'::regclass
  and contype = 'c';