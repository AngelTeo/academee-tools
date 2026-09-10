# EvalGo_ATC · Post-Report Build Plan v1

Date: 2026-09-10 MYT
Branch: `evalgo-paper-instance-prep-20260910`
Status: PREP ONLY · production v25 and September report path remain untouched

## Release objective

After the September parent report is safely produced, move EvalGo from the current one-paper-per-subject model to a canonical multi-paper evidence system that can later feed PTMGo.

Canonical chain:

`Exam -> Paper Instance -> Paper Scope -> Paper Teacher -> Paper Section -> Student Evidence -> Subject Summary / PTMGo`

## Stage 0 · Before report deadline

Keep production v25 unchanged.

Allowed preparation only:

- schema design;
- migration draft;
- regression design;
- read-only readiness checks;
- branch-only frontend work if isolated from production.

Do not change:

- `reportReady()` semantics;
- current `evalgo_paper_analysis` one-row-per-student+subject behavior used by v25;
- current natural unique keys;
- production HTML.

## Stage 1 · Additive Paper Instance foundation

After final preflight, apply only additive schema:

- create `evalgo_paper_instance`;
- create `evalgo_paper_scope`;
- create `evalgo_paper_teacher`;
- add nullable `paper_instance_id` to paper/evidence tables;
- backfill one Legacy Paper for each existing `(exam_id,subject,year_level)` group;
- backfill Legacy Paper scopes to matching active ATC classes;
- preserve every old `id`, `client_uid` and natural key;
- use RESTRICT / NO ACTION, not CASCADE, for paper/evidence deletion relationships.

Gate: all legacy rows map with zero ambiguity and zero orphan evidence.

## Stage 2 · Paper-aware natural identity

Only after the frontend is ready to read/write `paper_instance_id`:

- add paper-aware unique keys for `paper_section`, `live_obs`, `paper_analysis`, `wrong_item`, `essay_result`;
- verify no collision;
- switch write paths to paper-aware payloads;
- switch pull paths to preserve `paper_instance_id`;
- only then retire old natural keys that block multiple papers.

Never change `client_uid` or primary keys.

## Stage 3 · Multi-paper teacher workflow

Teacher workflow target:

1. choose class + subject;
2. choose an existing Paper or create another Paper if allowed;
3. Paper screen clearly shows its label/display number;
4. all Section / Observation / Analysis / Wrong Item / Essay evidence is stored under that Paper Instance;
5. same teacher may work on Paper A and Paper B;
6. multiple teachers may be assigned to the same Paper;
7. different teachers may be assigned to different Papers for the same class+subject.

General class/subject responsibility remains in `evalgo_teacher_assign`.
Paper-specific responsibility lives in `evalgo_paper_teacher`.

## Stage 4 · Controlled delete

Implement `EvalGo_Controlled_Delete_Contract_v1_20260910.md`.

Critical gates:

- destructive controls require existing `CLOUD.perm.can_approve`;
- backup must be created before destructive writes;
- browser backup failure cancels deletion;
- child evidence is deleted explicitly;
- every DELETE verifies returned affected rows;
- zero-row RLS delete is failure;
- parent Paper/Section is deleted last;
- final read-back confirms absence;
- no cascade-based evidence destruction.

## Stage 5 · Owner Global View

Management screen target:

| Class | Subject | Teacher | Paper | Pre-Obs | Paper Analysis | Status |
|---|---|---|---|---:|---:|---|

Must answer at a glance:

- who is responsible for each class/subject;
- which Paper(s) exist;
- who is responsible for each Paper;
- whether observations have started;
- whether paper analysis is complete;
- which rows are Not Started / In Progress / Complete / Archived.

Legacy compatibility may temporarily fall back to `evalgo_teacher_assign` until `evalgo_paper_teacher` is populated for new paper-specific work.

## Stage 6 · Report / PTMGo separation

Do not keep future reports dependent on one mutable paper-analysis row per subject.

Long-term separation:

- Paper-level evidence remains attached to Paper Instance;
- subject-level summary is derived from one or more Paper Instances;
- PTMGo consumes the derived academic evidence/summary with provenance back to Paper Instance;
- historical paper evidence remains traceable even after later papers are added.

This avoids making PTMGo guess which paper produced a claim.

## Stage 7 · Regression gates

New regression suite must prove at minimum:

1. Paper A Q3 and Paper B Q3 coexist;
2. two Papers may both have Section A;
3. same teacher can access two Papers;
4. two teachers can share one Paper;
5. two teachers can own different Papers in same class+subject;
6. pull preserves `paper_instance_id` for every paper-aware payload;
7. old Legacy rows still load;
8. September-compatible subject summary remains readable;
9. delete zero-row response is treated as failure;
10. backup failure prevents deletion;
11. no paper/evidence FK uses CASCADE;
12. Owner Global View counts are derived from cloud data, not local state.

## Current blocker status

No Owner decision is required now.

Production remains on v25 until the September parent report is safely completed. All current work is preparation on the isolated branch.