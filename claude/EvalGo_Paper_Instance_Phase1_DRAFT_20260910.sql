-- EvalGo_ATC · Paper Instance Phase 1 DRAFT
-- Date: 2026-09-10 MYT
-- STATUS: DRAFT ONLY. DO NOT RUN ON PRODUCTION BEFORE REVIEW.
-- Goal: additive, v25-neutral preparation for canonical Paper Instance model.
-- Explicitly does NOT drop old unique keys, does NOT set new columns NOT NULL,
-- does NOT change current report semantics, and does NOT use ON DELETE CASCADE.

-- ================================================================
-- PHASE 0 · PRECHECK
-- ================================================================

select to_char(now() at time zone 'Asia/Kuala_Lumpur','YYYY-MM-DD HH24:MI:SS') as now_myt,
       (select count(*) from public.evalgo_paper_section) as paper_section,
       (select count(*) from public.evalgo_live_obs) as live_obs,
       (select count(*) from public.evalgo_paper_analysis) as paper_analysis,
       (select count(*) from public.evalgo_wrong_item) as wrong_item,
       (select count(*) from public.evalgo_essay_result) as essay_result,
       (select count(*) from public.evalgo_teacher_assign) as teacher_assign;

select count(*) as legacy_groups
from (
  select exam_id,subject,year_level from public.evalgo_paper_section
  union select exam_id,subject,year_level from public.evalgo_live_obs
  union select exam_id,subject,year_level from public.evalgo_paper_analysis
  union select exam_id,subject,year_level from public.evalgo_wrong_item
  union select exam_id,subject,year_level from public.evalgo_essay_result
) s;

select
  (select count(*) from public.evalgo_wrong_item where section_id is null) as wrong_item_section_null,
  (select count(*) from public.evalgo_essay_result where section_id is null) as essay_section_null,
  (select count(*) from public.evalgo_wrong_item w left join public.evalgo_paper_section p on p.id=w.section_id where w.section_id is not null and p.id is null) as wrong_item_orphan_fk,
  (select count(*) from public.evalgo_essay_result e left join public.evalgo_paper_section p on p.id=e.section_id where e.section_id is not null and p.id is null) as essay_orphan_fk;

-- STOP if unexpected ambiguity/orphans are discovered.

-- ================================================================
-- PHASE 1 · CREATE CANONICAL PAPER TABLES
-- ================================================================

create table public.evalgo_paper_instance (
  id uuid primary key default gen_random_uuid(),
  exam_id uuid not null references public.evalgo_exam(id) on delete restrict,
  subject text not null,
  year_level smallint not null,
  label text not null,
  display_no smallint,
  status text not null default 'ACTIVE' check (status in ('ACTIVE','ARCHIVED')),
  sort_order integer not null default 0,
  created_by text references public.teachers(id) on delete no action,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  client_uid text not null default gen_random_uuid()::text,
  constraint evalgo_paper_instance_client_uid_key unique (client_uid)
);

-- Human-facing labels are intentionally NOT unique. Two real papers may share a label.

alter table public.evalgo_paper_instance enable row level security;

grant select, insert, update, delete on public.evalgo_paper_instance to authenticated;

create policy evalgo_pi_sel on public.evalgo_paper_instance
for select to authenticated
using ((select can_see from can_access('RPT-EvalGo-ATC')));

create policy evalgo_pi_ins on public.evalgo_paper_instance
for insert to authenticated
with check ((select can_edit from can_access('RPT-EvalGo-ATC')));

create policy evalgo_pi_upd on public.evalgo_paper_instance
for update to authenticated
using ((select can_edit from can_access('RPT-EvalGo-ATC')))
with check ((select can_edit from can_access('RPT-EvalGo-ATC')));

create policy evalgo_pi_del on public.evalgo_paper_instance
for delete to authenticated
using ((select can_approve from can_access('RPT-EvalGo-ATC')));

-- No grants to anon.

create table public.evalgo_paper_scope (
  id uuid primary key default gen_random_uuid(),
  paper_instance_id uuid not null references public.evalgo_paper_instance(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint evalgo_paper_scope_unique unique (paper_instance_id,class_id)
);

alter table public.evalgo_paper_scope enable row level security;
grant select, insert, update, delete on public.evalgo_paper_scope to authenticated;

create policy evalgo_pscope_sel on public.evalgo_paper_scope
for select to authenticated
using ((select can_see from can_access('RPT-EvalGo-ATC')));
create policy evalgo_pscope_ins on public.evalgo_paper_scope
for insert to authenticated
with check ((select can_edit from can_access('RPT-EvalGo-ATC')));
create policy evalgo_pscope_upd on public.evalgo_paper_scope
for update to authenticated
using ((select can_edit from can_access('RPT-EvalGo-ATC')))
with check ((select can_edit from can_access('RPT-EvalGo-ATC')));
create policy evalgo_pscope_del on public.evalgo_paper_scope
for delete to authenticated
using ((select can_approve from can_access('RPT-EvalGo-ATC')));

create table public.evalgo_paper_teacher (
  id uuid primary key default gen_random_uuid(),
  paper_instance_id uuid not null references public.evalgo_paper_instance(id) on delete restrict,
  class_id uuid not null references public.classes(id) on delete restrict,
  teacher_id text not null references public.teachers(id) on delete no action,
  role text not null default 'EDITOR',
  created_at timestamptz not null default now(),
  constraint evalgo_paper_teacher_unique unique (paper_instance_id,class_id,teacher_id)
);

alter table public.evalgo_paper_teacher enable row level security;
grant select, insert, update, delete on public.evalgo_paper_teacher to authenticated;

create policy evalgo_pteacher_sel on public.evalgo_paper_teacher
for select to authenticated
using ((select can_see from can_access('RPT-EvalGo-ATC')));
create policy evalgo_pteacher_ins on public.evalgo_paper_teacher
for insert to authenticated
with check ((select can_edit from can_access('RPT-EvalGo-ATC')));
create policy evalgo_pteacher_upd on public.evalgo_paper_teacher
for update to authenticated
using ((select can_edit from can_access('RPT-EvalGo-ATC')))
with check ((select can_edit from can_access('RPT-EvalGo-ATC')));
create policy evalgo_pteacher_del on public.evalgo_paper_teacher
for delete to authenticated
using ((select can_approve from can_access('RPT-EvalGo-ATC')));

-- ================================================================
-- PHASE 2 · ADD NULLABLE PAPER INSTANCE FKs TO EVIDENCE TABLES
-- ================================================================

alter table public.evalgo_paper_section
  add column paper_instance_id uuid references public.evalgo_paper_instance(id) on delete restrict;

alter table public.evalgo_live_obs
  add column paper_instance_id uuid references public.evalgo_paper_instance(id) on delete restrict;

alter table public.evalgo_paper_analysis
  add column paper_instance_id uuid references public.evalgo_paper_instance(id) on delete restrict;

alter table public.evalgo_wrong_item
  add column paper_instance_id uuid references public.evalgo_paper_instance(id) on delete restrict;

alter table public.evalgo_essay_result
  add column paper_instance_id uuid references public.evalgo_paper_instance(id) on delete restrict;

-- Existing v25 ignores these nullable columns.

-- ================================================================
-- PHASE 3 · BACKFILL ONE LEGACY PAPER PER EXISTING GROUP
-- ================================================================

-- `teachers.id='system'` does not exist in production as of 2026-09-10.
-- Preserve provenance honestly: system-generated legacy rows use created_by = NULL.
insert into public.evalgo_paper_instance
  (exam_id,subject,year_level,label,status,sort_order,created_by)
select g.exam_id,g.subject,g.year_level,'Legacy','ACTIVE',0,NULL
from (
  select exam_id,subject,year_level from public.evalgo_paper_section
  union select exam_id,subject,year_level from public.evalgo_live_obs
  union select exam_id,subject,year_level from public.evalgo_paper_analysis
  union select exam_id,subject,year_level from public.evalgo_wrong_item
  union select exam_id,subject,year_level from public.evalgo_essay_result
) g
where not exists (
  select 1 from public.evalgo_paper_instance pi
  where pi.exam_id=g.exam_id
    and pi.subject=g.subject
    and pi.year_level=g.year_level
    and pi.label='Legacy'
);

update public.evalgo_paper_section x
set paper_instance_id=pi.id
from public.evalgo_paper_instance pi
where pi.label='Legacy'
  and pi.exam_id=x.exam_id
  and pi.subject=x.subject
  and pi.year_level=x.year_level
  and x.paper_instance_id is null;

update public.evalgo_live_obs x
set paper_instance_id=pi.id
from public.evalgo_paper_instance pi
where pi.label='Legacy'
  and pi.exam_id=x.exam_id
  and pi.subject=x.subject
  and pi.year_level=x.year_level
  and x.paper_instance_id is null;

update public.evalgo_paper_analysis x
set paper_instance_id=pi.id
from public.evalgo_paper_instance pi
where pi.label='Legacy'
  and pi.exam_id=x.exam_id
  and pi.subject=x.subject
  and pi.year_level=x.year_level
  and x.paper_instance_id is null;

update public.evalgo_wrong_item x
set paper_instance_id=pi.id
from public.evalgo_paper_instance pi
where pi.label='Legacy'
  and pi.exam_id=x.exam_id
  and pi.subject=x.subject
  and pi.year_level=x.year_level
  and x.paper_instance_id is null;

update public.evalgo_essay_result x
set paper_instance_id=pi.id
from public.evalgo_paper_instance pi
where pi.label='Legacy'
  and pi.exam_id=x.exam_id
  and pi.subject=x.subject
  and pi.year_level=x.year_level
  and x.paper_instance_id is null;

-- ================================================================
-- PHASE 4 · OPTIONAL LEGACY CLASS SCOPE BACKFILL
-- ================================================================
-- ATC production currently has one active class ATC1..ATC6 for year 1..6.
-- This maps legacy year-level papers to their matching ATC class.

insert into public.evalgo_paper_scope (paper_instance_id,class_id)
select pi.id,c.id
from public.evalgo_paper_instance pi
join public.classes c
  on c.department='ATC'
 and c.is_active=true
 and c.class_name=('ATC' || pi.year_level::text)
where pi.label='Legacy'
on conflict (paper_instance_id,class_id) do nothing;

-- Deliberately DO NOT auto-fill evalgo_paper_teacher here.
-- Existing evalgo_teacher_assign remains the responsibility registry.
-- Paper-specific teacher links should only be created when the multi-paper UI opens.

-- ================================================================
-- PHASE 5 · VALIDATION GATE
-- ================================================================

select
 (select count(*) from public.evalgo_paper_instance where label='Legacy') as legacy_paper_count,
 (select count(*) from public.evalgo_paper_section where paper_instance_id is null) as ps_null,
 (select count(*) from public.evalgo_live_obs where paper_instance_id is null) as lo_null,
 (select count(*) from public.evalgo_paper_analysis where paper_instance_id is null) as pa_null,
 (select count(*) from public.evalgo_wrong_item where paper_instance_id is null) as wi_null,
 (select count(*) from public.evalgo_essay_result where paper_instance_id is null) as es_null,
 (select count(*) from public.evalgo_paper_scope s join public.evalgo_paper_instance p on p.id=s.paper_instance_id where p.label='Legacy') as legacy_scope_count;

-- Expected at the 2026-09-10 design snapshot:
-- legacy_paper_count = 22
-- ps_null = 0
-- lo_null = 0
-- pa_null = 0
-- wi_null = 0
-- es_null = 0
-- legacy_scope_count = 22
-- Recompute immediately before any production execution; do not rely on these snapshot counts.

-- ================================================================
-- NOT PART OF PHASE 1 / DO NOT EXECUTE BEFORE SEPTEMBER REPORT
-- ================================================================
-- * no new paper-aware natural unique keys yet
-- * no dropping existing natural unique keys
-- * no NOT NULL conversion of paper_instance_id
-- * no paper-aware report rewrite
-- * no v25 production HTML change
-- * no controlled-delete UI yet
