-- ObsGo · Workspace / Management Separation · RLS v1
-- 2026-09-12
-- STATUS: STAGED FOR REVIEW/APPLY. Direct DB SQL execution was unavailable in the current tool session.
-- Owner lock: Workspace own records only; Management team data only for OWNER/TOP_MGMT/ADMIN.
--
-- IMPORTANT:
-- 1) This migration intentionally does NOT grant DELETE.
-- 2) Existing ObsGo frontend writes created_by as display_name. This migration adds immutable created_by_uid.
-- 3) Legacy ownership backfill is only performed where display_name maps to exactly one users_meta user.
-- 4) Ambiguous/unmapped legacy rows remain NULL and are management-readable only until manually resolved.

begin;

alter table public.obsgo_visit
  add column if not exists created_by_uid uuid references auth.users(id);

create index if not exists obsgo_visit_created_by_uid_idx
  on public.obsgo_visit(created_by_uid);

-- Safe legacy backfill: only unique display-name mappings.
with unique_names as (
  select upper(trim(display_name)) as nm, min(user_id) as user_id
  from public.users_meta
  where display_name is not null and trim(display_name) <> ''
  group by upper(trim(display_name))
  having count(*) = 1
)
update public.obsgo_visit v
set created_by_uid = u.user_id
from unique_names u
where v.created_by_uid is null
  and upper(trim(coalesce(v.created_by,''))) = u.nm;

-- New browser inserts automatically bind ownership to the authenticated user.
alter table public.obsgo_visit
  alter column created_by_uid set default auth.uid();

-- Helper is private: management authorization must not become a public RPC endpoint.
create schema if not exists private;

create or replace function private.obsgo_is_management()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users_meta um
    where um.user_id = (select auth.uid())
      and um.role in ('OWNER','TOP_MGMT','ADMIN')
  );
$$;

revoke all on function private.obsgo_is_management() from public;
grant usage on schema private to authenticated;
grant execute on function private.obsgo_is_management() to authenticated;

alter table public.obsgo_visit enable row level security;
alter table public.obsgo_entry enable row level security;
alter table public.obsgo_class_entry enable row level security;

-- Remove existing policies on the three ObsGo data tables so permissive old policies
-- cannot OR together with the new ownership rules and reopen Team data.
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname='public'
      and tablename in ('obsgo_visit','obsgo_entry','obsgo_class_entry')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- VISIT: own Workspace rows OR authorized Management rows.
create policy "ObsGo read own or management visits"
on public.obsgo_visit for select to authenticated
using (
  created_by_uid = (select auth.uid())
  or (select private.obsgo_is_management())
);

create policy "ObsGo insert own visits"
on public.obsgo_visit for insert to authenticated
with check (
  created_by_uid = (select auth.uid())
);

create policy "ObsGo update own visits"
on public.obsgo_visit for update to authenticated
using (created_by_uid = (select auth.uid()))
with check (created_by_uid = (select auth.uid()));

-- CHILD ROWS inherit authorization through parent visit.
create policy "ObsGo read own or management student entries"
on public.obsgo_entry for select to authenticated
using (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_entry.visit_id
      and (v.created_by_uid = (select auth.uid()) or (select private.obsgo_is_management()))
  )
);

create policy "ObsGo insert own student entries"
on public.obsgo_entry for insert to authenticated
with check (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_entry.visit_id
      and v.created_by_uid = (select auth.uid())
  )
);

create policy "ObsGo update own student entries"
on public.obsgo_entry for update to authenticated
using (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_entry.visit_id
      and v.created_by_uid = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_entry.visit_id
      and v.created_by_uid = (select auth.uid())
  )
);

create policy "ObsGo read own or management class entries"
on public.obsgo_class_entry for select to authenticated
using (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_class_entry.visit_id
      and (v.created_by_uid = (select auth.uid()) or (select private.obsgo_is_management()))
  )
);

create policy "ObsGo insert own class entries"
on public.obsgo_class_entry for insert to authenticated
with check (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_class_entry.visit_id
      and v.created_by_uid = (select auth.uid())
  )
);

create policy "ObsGo update own class entries"
on public.obsgo_class_entry for update to authenticated
using (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_class_entry.visit_id
      and v.created_by_uid = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.obsgo_visit v
    where v.id = obsgo_class_entry.visit_id
      and v.created_by_uid = (select auth.uid())
  )
);

-- No DELETE policies by design.
revoke delete on public.obsgo_visit, public.obsgo_entry, public.obsgo_class_entry from anon, authenticated;

commit;

-- Required post-apply verification:
-- ordinary authorized observer:
--   SELECT own visit => PASS
--   SELECT other observer visit => 0 rows / DENIED
--   direct child-row read for other visit => 0 rows / DENIED
--   UPDATE other visit => DENIED
-- management role:
--   SELECT team visits => PASS
--   SELECT team child rows => PASS
-- anon:
--   all three tables => DENIED
