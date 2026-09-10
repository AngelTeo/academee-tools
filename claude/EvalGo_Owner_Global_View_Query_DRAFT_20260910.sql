-- EvalGo_ATC · Owner Global View Query DRAFT
-- Date: 2026-09-10 MYT
-- STATUS: POST-REPORT / depends on Paper Instance Phase 1 tables.
-- Purpose: one management row per class + subject + teacher + paper.

with paper_base as (
  select
    p.id as paper_instance_id,
    p.exam_id,
    p.subject,
    p.year_level,
    p.label as paper_label,
    p.display_no,
    p.status,
    s.class_id,
    c.class_name
  from public.evalgo_paper_instance p
  join public.evalgo_paper_scope s on s.paper_instance_id=p.id
  join public.classes c on c.id=s.class_id
),
paper_teachers as (
  select
    pt.paper_instance_id,
    pt.class_id,
    pt.teacher_id,
    pt.role
  from public.evalgo_paper_teacher pt
),
student_scope as (
  select
    e.class_id,
    e.student_id
  from public.student_enrollments e
  where e.is_active=true
),
obs as (
  select
    paper_instance_id,
    class_id,
    count(*) as obs_rows,
    count(distinct student_id) as obs_students
  from public.evalgo_live_obs
  where paper_instance_id is not null
  group by paper_instance_id,class_id
),
pa as (
  select
    paper_instance_id,
    class_id,
    count(*) as analysis_rows,
    count(*) filter (where assess_status='ASSESSED') as assessed_rows,
    count(*) filter (where assess_status='ASSESSED' and paper_checked=true and tp is not null) as report_ready_rows
  from public.evalgo_paper_analysis
  where paper_instance_id is not null
  group by paper_instance_id,class_id
),
sec as (
  select paper_instance_id,count(*) as section_count
  from public.evalgo_paper_section
  where paper_instance_id is not null
  group by paper_instance_id
),
student_counts as (
  select class_id,count(distinct student_id) as enrolled_students
  from student_scope
  group by class_id
)
select
  b.class_name,
  b.subject,
  pt.teacher_id,
  b.paper_instance_id,
  b.paper_label,
  b.display_no,
  coalesce(sc.enrolled_students,0) as enrolled_students,
  coalesce(sec.section_count,0) as section_count,
  coalesce(obs.obs_students,0) as observed_students,
  coalesce(pa.analysis_rows,0) as analysis_rows,
  coalesce(pa.report_ready_rows,0) as report_ready_rows,
  case
    when b.status='ARCHIVED' then 'ARCHIVED'
    when coalesce(sc.enrolled_students,0)=0 then 'NO_STUDENTS'
    when coalesce(pa.report_ready_rows,0) >= coalesce(sc.enrolled_students,0) then 'COMPLETE'
    when coalesce(obs.obs_students,0)=0 and coalesce(pa.analysis_rows,0)=0 then 'NOT_STARTED'
    else 'IN_PROGRESS'
  end as status
from paper_base b
left join paper_teachers pt
  on pt.paper_instance_id=b.paper_instance_id and pt.class_id=b.class_id
left join student_counts sc on sc.class_id=b.class_id
left join obs on obs.paper_instance_id=b.paper_instance_id and obs.class_id=b.class_id
left join pa on pa.paper_instance_id=b.paper_instance_id and pa.class_id=b.class_id
left join sec on sec.paper_instance_id=b.paper_instance_id
order by b.class_name,b.subject,coalesce(b.display_no,999),b.paper_label,pt.teacher_id;

-- September compatibility note:
-- before multi-paper UI opens, `evalgo_paper_teacher` may intentionally be empty.
-- For Legacy Paper management display, the UI/query layer may fall back to
-- `evalgo_teacher_assign` by exam_id + class_name + subject ONLY as a compatibility bridge.
-- That fallback must be removed for new paper-specific assignments once Paper Teacher is populated.
