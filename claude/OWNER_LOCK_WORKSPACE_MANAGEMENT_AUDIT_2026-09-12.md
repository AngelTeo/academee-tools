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

### A3 Management surface — FAIL

Current `screen-manage` is actually system Settings/Diagnostics (identity, system info, cloud, backup, advanced). It is not the required operational Management surface.

Required architecture:
- `ObsGo.html` = Workspace + My Records + Settings as applicable;
- separate `ObsGo_Management.html` (or equivalent independent route) = Work Progress / All Observations / Missing / Overdue / Analysis / Follow-up.
- Management entry visible only to authorized management roles.

### A4 Data authorization — FAIL / SECURITY P0

Current code explicitly documents that `obsgo_visit_sel` does not split by `created_by` and is based on `can_access.can_see`. `pullMyVisits()` filters `.eq('created_by', me)` only in the client. `pullTeamVisits()` performs an unscoped select of all `obsgo_visit` rows.

Therefore My Records is presently a UI/client filter, not a database security boundary. An ordinary account that has ObsGo `can_see` can potentially issue a direct Data API query for other users’ rows if RLS really remains as documented in v7.

Required RLS contract:
- ordinary authorized Workspace user: SELECT own `obsgo_visit` only;
- management role: SELECT all authorized team `obsgo_visit` rows;
- `obsgo_entry` / `obsgo_class_entry`: same access inherited through parent visit ownership/management authorization;
- INSERT/UPDATE: own visit only unless an explicitly approved management workflow exists;
- direct other-user read must fail even when UI is bypassed.

### A5 Identity key risk — P0 design defect

`created_by` is written from `users_meta.display_name` uppercased (`CLOUD.who.initials`) rather than immutable `auth.uid()`. `pullMyVisits()` also identifies ownership by display name.

Display name is not a safe ownership key: it can change and is not guaranteed globally unique.

Required fix:
- authoritative ownership must use immutable Auth UID (`created_by_uid uuid` or equivalent);
- display name remains presentation/audit label only;
- legacy rows need a controlled backfill/mapping path; do not guess ambiguous identities.

This is an engineering correction, not an Owner decision: identity/ownership security requires immutable IDs.

### A6 Workspace wording — FAIL

Current Student tab says `管理层要看的是全班` and several comments/UI strings frame normal data entry as a management-only experience. Under the new architecture, Workspace copy must describe the work itself, not management surveillance.

Required copy direction: `这次巡班目标是覆盖全班；可以分几次完成。没被加入 ≠ 低分。`

### A7 Existing good behavior to preserve

Do NOT regress:
- draft / completed / cancelled state distinction;
- Save / Resume / Exit behavior;
- cloud restore of own drafts;
- no-delete / void model;
- authoritative evidence = completed only;
- student_id UUID keys;
- class-id healing fail-closed behavior;
- duplicate natural-key protection;
- Evidence / Support→Response / Shared Interpretation logic;
- SRK/SRT/ATC/GAK academic dictionaries.

---

## B. EvalGo_ATC v26 · audit direction

Source: `EvalGo_ATC.html` main, blob `590b2de9542eddb37c5187db7bb29870d4585b68`.

Visible navigation currently includes normal work pages (`工作台`, `考前观察`, `考卷分析`, `覆盖追踪`) plus role-hidden `考前报告` and `设定`.

The lock requires a semantic audit, not merely checking hidden tabs:
- any teacher/team completion tracking, cross-user coverage, missing/overdue, team filters or manager follow-up must leave the normal Workspace;
- teacher Workspace must default to own assigned work;
- Owner entering Workspace must see the same normal work UX;
- Report/Management generation authority must be separated from teacher data-entry flow where it is team-level.

No change may break the exam-before-ParentGo reporting requirement or multi-paper v26 model.

---

## C. LoveGo · architecture gate

No `LoveGo.html` is present in repository root as of this audit. Database objects/functions exist, but the user-facing trial Workspace is not yet a deployed root artifact.

Before teacher trial:
- Teacher Workspace = only assigned students/classes/reviews and own completion state;
- Management = assignment setup, cross-teacher progress, recommendations approval, exceptions, report authority, team analytics;
- one teacher / one department / one class / selected students trial must be possible without exposing team management controls;
- test-data cleanup must be scoped and auditable, not broad production deletion.

---

## D. ParentGo / PTMGo

Current repository has `parent-go.html`; it must be treated as legacy/current artifact to audit against the new separation rule, not assumed compliant because it is management-oriented.

PTMGo/ParentGo target remains:
Teacher input/evidence consumption → PTM live view + parent report + Report Card comment + Next Step.
Management Report Gate remains manager-side.

Required separation:
- PTM day/teacher Workspace = assigned student profile, talking points, evidence, permitted report workflow;
- Management = all-student readiness, missing evidence, report gates, completion analysis, cross-user follow-up;
- Owner testing teacher Workspace must not default to team dashboards.

---

## E. Mandatory contract tests for every applicable system

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
