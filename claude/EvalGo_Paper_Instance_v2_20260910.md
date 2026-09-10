# EvalGo_ATC · Paper Instance Architecture v2

Date: 2026-09-10 MYT
Status: DESIGN LOCK CANDIDATE · no production DB change · no production HTML change
Branch: `evalgo-paper-instance-prep-20260910`

## 1. Current production facts

Read-only checks at 2026-09-10 20:38 MYT:

- `evalgo_paper_section`: 73
- `evalgo_live_obs`: 84
- `evalgo_paper_analysis`: 15
- `evalgo_wrong_item`: 3
- `evalgo_essay_result`: 0
- `evalgo_teacher_assign`: 13
- distinct legacy `(exam_id, subject, year_level)` groups: 22
- current `wrong_item.section_id IS NULL`: 0
- current `essay_result.section_id IS NULL`: 0
- current orphan section FK rows: 0

The September report path remains live. Existing v25 `reportReady()` depends on `evalgo_paper_analysis` semantics and must not be changed before the 2026-09-15 report deadline.

## 2. Canonical model

The canonical long-term model is:

`Exam -> Paper Instance -> Paper Scope -> Paper Teacher -> Paper Section -> Student Evidence`

### 2.1 `evalgo_paper_instance`

A paper instance is the real identity of one assessment paper. It is not merely `paper_no`.

Minimum fields:

- `id uuid primary key`
- `exam_id uuid not null`
- `subject text not null`
- `year_level smallint not null`
- `label text not null`
- `display_no smallint null` — optional user-facing 卷一/卷二/卷三 order
- `status text not null default 'ACTIVE'` — `ACTIVE | ARCHIVED`
- `sort_order int not null default 0`
- `created_by text null`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz null`
- `client_uid text not null`

Identity rules:

- `id` is authoritative FK identity.
- `client_uid` must be unique for sync identity.
- `label` is display data, not FK identity.
- do not use `paper_no` as the canonical identity.

### 2.2 `evalgo_paper_scope`

Purpose: one paper may be used by one or more ATC classes without duplicating the paper structure.

Fields:

- `id uuid primary key`
- `paper_instance_id uuid not null`
- `class_id uuid not null`
- `created_at timestamptz not null default now()`
- unique `(paper_instance_id, class_id)`

This is deliberately separate from `evalgo_teacher_assign`.

### 2.3 `evalgo_paper_teacher`

Purpose: support multiple teachers on the same paper and the same teacher on multiple papers.

Fields:

- `id uuid primary key`
- `paper_instance_id uuid not null`
- `class_id uuid not null`
- `teacher_id text not null`
- `role text not null default 'EDITOR'`
- `created_at timestamptz not null default now()`
- unique `(paper_instance_id, class_id, teacher_id)`

`evalgo_teacher_assign` remains the existing class/subject responsibility registry and is not given a `paper_instance_id` FK. This avoids coupling a teacher's general subject responsibility to exactly one paper.

## 3. Evidence mapping

Long-term provenance rule:

> Any evidence that can differ between Paper A and Paper B must be able to identify the originating `paper_instance_id`.

### 3.1 `evalgo_paper_section`

Must have `paper_instance_id`.

Reason: two papers can both contain Section A. Existing natural identity `(exam_id, subject, year_level, code)` cannot support that.

### 3.2 `evalgo_wrong_item`

Must have `paper_instance_id`.

Reason: Paper 1 Q3 and Paper 2 Q3 are different evidence. Existing unique key `(exam_id, student_id, subject, q_no)` collides.

### 3.3 `evalgo_essay_result`

Must have `paper_instance_id`.

Reason: two papers may have the same section code and represent different work.

### 3.4 `evalgo_live_obs`

Must become paper-aware long-term.

Reason: current identity `(exam_id, student_id, subject, bahagian)` collides if two papers both contain Bahagian A. v25 does not yet expose multi-paper, so this change can remain dormant until the post-report UI release.

### 3.5 `evalgo_paper_analysis`

Long-term must be paper-aware because it contains paper-level evidence such as `paper_date`, `paper_checked`, item-count outputs and weakness evidence.

However, September compatibility is special:

- existing v25 treats this table as one subject-level row per student+subject;
- `reportReady()` expects this one-row model;
- therefore the 2026-09-15 report path must remain unchanged.

Canonical future separation:

1. `evalgo_paper_analysis` = paper-level analysis evidence, keyed by paper instance.
2. subject-level PTM/report summary = derived aggregation / later dedicated summary layer, not by flattening multiple papers into one evidence row.

## 4. September compatibility strategy

Before 2026-09-15:

- keep v25 production HTML unchanged;
- keep all current natural unique keys unchanged;
- do not open multi-paper UI;
- do not change `reportReady()`;
- do not change current report query semantics;
- additive schema may be prepared only if it is proven v25-neutral.

Legacy backfill strategy:

- create one `Legacy` paper instance for each existing `(exam_id, subject, year_level)` group;
- there are currently 22 groups;
- existing rows receive the matching `Legacy` `paper_instance_id`;
- this does not change current report behavior because v25 does not read the new column.

## 5. FK delete strategy

Do not use `ON DELETE CASCADE` from `paper_instance` or `paper_section` to student evidence.

Preferred rule:

- `paper_instance` dependent rows: `ON DELETE RESTRICT` / `NO ACTION`
- `paper_section` evidence FK: migrate away from current `SET NULL` to `RESTRICT`

Rationale:

- preserve provenance;
- prevent one accidental parent DELETE from removing or detaching student evidence;
- force all destructive operations through the controlled application delete flow.

## 6. Controlled delete contract

### 6.1 Section with no student evidence

Authorized user may delete directly, but the cloud DELETE must return the deleted row using `.delete().select()`.

`data.length === 0` means failure, even if there is no exception.

### 6.2 Section with evidence

Flow:

1. query affected `wrong_item` + `essay_result` rows;
2. show exact student/evidence counts;
3. user confirms permanent deletion;
4. generate full JSON backup containing section + all affected evidence + `_meta`;
5. browser download must succeed;
6. delete child rows explicitly, each with `.delete().select()` and affected-row verification;
7. delete section last, also with affected-row verification;
8. final read-back confirms section no longer exists.

No FK cascade is used as a substitute for these checks.

### 6.3 Whole-paper delete

Same pattern, expanded to all sections and all paper-level evidence. The system must enumerate affected rows before deletion, backup first, then delete in controlled child-to-parent order.

## 7. Owner Global View target

Data model must support:

| Class | Subject | Teacher | Paper | Pre-Obs | Paper Analysis | Status |
|---|---|---|---|---:|---:|---|

This is built from:

- `evalgo_teacher_assign` — general responsibility
- `evalgo_paper_scope` — paper/class use
- `evalgo_paper_teacher` — teacher/paper responsibility
- `evalgo_paper_instance` — paper identity
- evidence tables — progress counts

## 8. Release gates

### Gate A — before 2026-09-15

Allowed only if proven v25-neutral:

- new paper tables
- nullable `paper_instance_id` columns
- Legacy backfill
- RLS matching existing EvalGo authenticated permission pattern

Not allowed before report deadline:

- drop/replace current natural unique keys
- make `paper_instance_id` NOT NULL
- open multi-paper UI
- change report gate semantics
- change `evalgo_paper_analysis` one-row behavior used by v25

### Gate B — after report completion

Then perform:

- new paper-aware unique keys
- new multi-paper UI
- paper-aware `live_obs`
- paper-aware `paper_analysis`
- controlled delete UI
- Owner Global View
- PTMGo academic evidence integration

## 9. Current decision status

No Owner decision is required for the architecture above.

The first genuine Owner decision boundary will be reached only if production evidence cannot be unambiguously backfilled, or if the September report must change before 2026-09-15. Current read-only checks show neither condition.