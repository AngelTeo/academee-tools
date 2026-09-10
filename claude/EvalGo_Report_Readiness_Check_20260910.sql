-- EvalGo_ATC · September report readiness · READ ONLY
-- Safe to run repeatedly. No DDL/DML.

with a as (
  select class_name,subject,count(*) teachers
  from public.evalgo_teacher_assign
  group by class_name,subject
), pa as (
  select c.class_name,p.subject,
         count(*) total_rows,
         count(*) filter (where p.assess_status='ASSESSED') assessed,
         count(*) filter (
           where p.assess_status='ASSESSED'
             and p.paper_checked=true
             and p.tp is not null
             and btrim(p.tp) <> ''
         ) report_ready,
         count(*) filter (where p.assess_status='ABSENT') absent,
         count(*) filter (where p.assess_status='NOT_ASSESSED') not_assessed
  from public.evalgo_paper_analysis p
  join public.classes c on c.id=p.class_id
  group by c.class_name,p.subject
), lo as (
  select c.class_name,l.subject,
         count(*) obs_rows,
         count(distinct l.student_id) students_with_obs
  from public.evalgo_live_obs l
  join public.classes c on c.id=l.class_id
  group by c.class_name,l.subject
)
select a.class_name,a.subject,a.teachers,
       coalesce(lo.obs_rows,0) obs_rows,
       coalesce(lo.students_with_obs,0) students_with_obs,
       coalesce(pa.total_rows,0) analysis_rows,
       coalesce(pa.assessed,0) assessed,
       coalesce(pa.report_ready,0) report_ready,
       coalesce(pa.absent,0) absent,
       coalesce(pa.not_assessed,0) not_assessed
from a
left join lo using(class_name,subject)
left join pa using(class_name,subject)
order by a.class_name,a.subject;
