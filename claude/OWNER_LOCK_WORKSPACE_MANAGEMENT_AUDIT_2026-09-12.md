# OWNER LOCK · WORKSPACE / MANAGEMENT SEPARATION · IMPLEMENTATION AUDIT

Date: 2026-09-12
Owner: Teo
Scope: ObsGo / EvalGo_ATC / LoveGo / PTMGo-ParentGo / future systems
Status: ACTIVE · supersedes role-conditioned TEAM-in-Workspace designs

## Canonical rule

> Identity decides whether a user may enter Management. Identity must not change the normal Workspace experience.

Normal Workspace = My Work / My Records / Resume / Edit / Complete.
Management = Team Records / Work Progress / Missing / Overdue / Analysis / Follow-up.
Management must be a separate surface and separately authorized at UI + database/RLS level.

---

## A. ObsGo v7 · FAIL · remediation required

Source: `ObsGo.html` main, blob `63d486b48d3b3c99c9e6e96de108bb2e68e21d8a`.

### A1 Workspace separation — FAIL

Current `screen-select` contains `#team-panel` and `renderSelect()` always calls `renderTeamPanel()`.
For OWNER / TOP_MGMT / ADMIN, `initApp()` automatically calls `refreshTeam()`.
Result: management identity changes the normal巡班 Workspace and injects everyone’s progress above the normal class-selection flow.

Required fix:
- remove Team Progress from `screen-select`;
- remove `renderTeamPanel()` from normal Workspace rendering;
- remove automatic `refreshTeam()` from Workspace bootstrap;
- Owner Workspace must render the same normal巡班 flow as another authorized observer.

### A2 Records separation — FAIL

Current `screen-history` is one shared page. `renderHistory()` adds a role-conditioned `我的 / 全部人` scope toggle for management roles. `openTeamHistory()` changes `UIH.scope='team'` and reuses the same History surface.

This is exactly the abolished design: ordinary Records + Owner-only All/Team toggle.

Required fix:
- Workspace History becomes My Records only;
- delete/hard-disable Team scope from Workspace History;
- Team Records moves to a separate ObsGo Management surface.

### A3 Management surface — FAIL → separate surface created

Current `screen-manage` is actually system Settings/Diagnostics (identity, system info, cloud, backup, advanced). It is not the required operational Management surface.

A separate root artifact `ObsGo_Management.html` has now been created. It contains Work Progress / All Observations / Analysis and a direct role gate for OWNER / TOP_MGMT / ADMIN. This is the correct surface direction, but it is not considered security-complete until database RLS is changed and Workspace team controls are removed.

### A4 Data authorization — FAIL / SECURITY P0

Current code explicitly documents that `obsgo_visit_sel` does not split by `created_by` and is based on `can_access.can_see`. `pullMyVisits()` filters `.eq('created_by', me)` only in the client. `pullTeamVisits()` performs an unscoped select of all `obsgo_visit` rows.

Therefore My Records is presently a UI/client filter, not a database security boundary.

Required RLS contract:
- ordinary authorized Workspace user: SELECT own `obsgo_visit` only;
- management role: SELECT all authorized team `obsgo_visit` rows;
- `obsgo_entry` / `obsgo_class_entry`: same access inherited through parent visit ownership/management authorization;
- INSERT/UPDATE: own visit only unless an explicitly approved management workflow exists;
- direct other-user read must fail even when UI is bypassed.

A staged migration now exists at `claude/OBSGo_WORKSPACE_MANAGEMENT_RLS_v1.sql`. It adds immutable Auth UID ownership, management authorization, child-row inheritance, removes permissive old policies, and keeps DELETE revoked. It is NOT yet applied to production.

### A5 Identity key risk — P0 design defect

`created_by` is written from `users_meta.display_name` uppercased (`CLOUD.who.initials`) rather than immutable `auth.uid()`. `pullMyVisits()` also identifies ownership by display name.

Required fix:
- authoritative ownership uses immutable Auth UID (`created_by_uid`);
- display name remains presentation/audit label only;
- legacy rows backfill only on unique identity match; ambiguous rows fail closed.

### A6 Workspace wording — FAIL

Current Student tab says `管理层要看的是全班`. Workspace copy must describe the work itself, not management surveillance.

Required copy: `这次巡班目标是覆盖全班；可以分几次完成。没被加入 ≠ 低分。`

### A7 Existing good behavior to preserve

Do NOT regress draft/completed/cancelled, Save/Resume/Exit, cloud restore of own drafts, no-delete/void, authoritative completed-only evidence, student UUID identity, class healing fail-closed, duplicate natural-key protection, Evidence/Support→Response/Shared Interpretation, or academic dictionaries.

---

## B. EvalGo_ATC v26 · PARTIAL PASS / two separation defects

Source: `EvalGo_ATC.html` main, blob `590b2de9542eddb37c5187db7bb29870d4585b68`.

### B1 Main Workspace — PASS

`renderHome()` uses `asgMine()` and builds the dashboard from the logged-in teacher’s own class/subject assignments. It shows `我的总进度`. This matches the Owner lock: Owner entering the normal Workspace should consume the same own-assignment UX rather than automatically receiving Team Progress.

Preserve this behavior.

### B2 Coverage Tracking — FAIL

`renderCoverage()` calculates `myCls`, but then loops over **all `CLASSES`**, not `myCls`. It also explicitly says that when no teaching assignment is registered it will `显示全部`.

This violates the lock. A missing assignment must not widen the Workspace scope to all classes.

Required fix:
- Coverage Workspace loops only classes assigned to the current user for the current subject;
- no assignment → empty/setup state, never `show all`;
- all-teacher merged coverage belongs to Management only.

### B3 Cloud pull / direct data boundary — SECURITY AUDIT REQUIRED

The report layer comments state that `cloudPull()` pulls the whole exam without subject filtering so cross-subject reporting can be generated. This is valid for an authorized management/report surface, but must not imply that an ordinary Workspace user can directly read all teachers’ exam data.

RLS/data contract must be tested independently of UI:
- teacher Workspace → own/assigned evidence only;
- authorized Report/Management → permitted cross-subject/class evidence;
- ordinary direct Team query → DENIED.

### B4 Report and Settings surfaces — direction PASS

`考前报告` and `设定` are separate hidden pages/surfaces rather than Team controls injected into the main `工作台`. Keep them role-gated. Report authority must remain management-side and must not alter teacher Workspace defaults.

### B5 Preserve v26 exam truth

Do not regress multi-paper support, paper structure lock/delete protection, ABSENT vs NOT_ASSESSED vs ASSESSED semantics, Operational Resolved vs Assessment Complete vs Report Ready, paper_checked evidence truth, or the requirement to produce the pre-exam parent report before full PTMGo integration.

---

## C. LoveGo · NOT READY FOR TEACHER TRIAL FRONTEND

No `LoveGo.html` is present in repository root as of this audit. Database functions/objects exist, but the teacher-facing trial Workspace is not yet a deployed root artifact.

Before teacher trial:
- Teacher Workspace = only assigned students/classes/reviews and own completion state;
- Management = assignment setup, cross-teacher progress, recommendations approval, exceptions, report authority, team analytics;
- one teacher / one department / one class / selected students trial must be possible without exposing team management controls;
- test-data cleanup must be scoped and auditable, not broad production deletion.

Supabase security advisor currently flags multiple LoveGo `SECURITY DEFINER` functions as executable by authenticated users. This does not prove each function is exploitable, but it is a mandatory pre-trial security audit: every function must enforce management/assignment authorization internally or have EXECUTE revoked from roles that do not need it.

---

## D. `parent-go.html` · LEGACY MANAGEMENT ARTIFACT · SECURITY FAIL

Source blob `4f5baf695fff6152a48015995e8824844fd5a7eb`.

This artifact is a Parent Communication / Coverage management tool, not the future PTM teacher Workspace.

### D1 It is management by nature

It loads all active/enrolled student roster rows, all `parent_comms`, calculates department-wide Need Attention / Due Soon / Covered / Awaiting Reply, and provides cross-student timelines. This belongs on a Management surface, not a normal teacher Workspace.

### D2 Frontend authentication — FAIL / P0

The file contains a hard-coded management password (`MGMT_PW`) and stores a 12-hour `parentgo_session` timestamp in localStorage. This is not Supabase Auth authorization and cannot be accepted as a security boundary.

Required disposition:
- do not reuse this auth pattern in PTMGo/ParentGo;
- management access must use Shared SSO / Supabase Auth + server-side/RLS authorization;
- hard-coded management password path must be retired when this artifact is migrated/replaced.

### D3 Data scope — management-only

`syncStudents()` pulls all active enrolled roster rows; `syncComms()` pulls all communications. This is acceptable only if the whole artifact is explicitly a Management surface and RLS confirms unauthorized roles cannot call those reads directly.

### D4 PTMGo/ParentGo target remains separate

Teacher/PTM Workspace = assigned Student Profile / Talking Points / evidence / permitted report workflow.
Management = all-student readiness / missing evidence / Report Gate / completion analysis / cross-user follow-up.
Owner testing teacher Workspace must not default to this legacy all-student dashboard.

---

## E. Supabase cross-system security findings relevant to this lock

Security advisor run 2026-09-12 found:
- public backup tables with RLS disabled;
- several SECURITY DEFINER functions callable by anon and/or authenticated roles;
- `is_manager`, `user_role`, `user_has_dept` among exposed SECURITY DEFINER helpers;
- LoveGo management/mutation functions among authenticated-callable SECURITY DEFINER functions.

These are not all automatically Workspace/Management violations, but they prevent claiming the hard-security gate PASS until reviewed. UI hiding is insufficient.

---

## F. Mandatory contract tests for every applicable system

1. Owner opens Workspace → same normal work flow as equivalent ordinary authorized user.
2. Workspace default scope → own/assigned work only.
3. No Team Progress / All Staff / Analysis controls in Workspace.
4. Ordinary user direct Management route → DENIED.
5. Ordinary user direct Team Data API query → DENIED by RLS/data layer.
6. Ordinary user other-user record read → DENIED.
7. Authorized management opens Management → PASS.
8. Authorized management reads permitted Team data → PASS.
9. Management Progress / Missing / Overdue / Analysis / Follow-up → PASS.
10. Workspace Save / Resume / Edit / Complete regression → PASS.

No system may be marked CLOSED until all ten pass.
