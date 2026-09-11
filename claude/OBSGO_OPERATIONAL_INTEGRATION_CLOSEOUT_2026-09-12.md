# ObsGo · Operational + Integration Closeout

Date: 2026-09-12
Owner: Teo
Current status: **HOLD AT FINAL LIVE-SESSION REGRESSION / OWNER SECURITY BOUNDARY**

This document supersedes earlier ObsGo closeout assumptions where they conflict with the Owner Workspace/Management Separation lock or Integration Readiness Addendum.

## 1. Execution result

Sequence executed:

Operational Audit → Operational Fix → Workspace/Management Separation → Security/RLS Fix → Integration Role Classification → Evidence Output Plug v1 → Contract Tests → Production Migration → Static Deployment Routing.

ObsGo integration role = **SOURCE**.

It provides observation/evidence data to downstream PTMGo / ParentGo / reporting consumers through a stable read-only adapter. Consumers must not read ObsGo DOM, localStorage, UI labels, or internal table layout directly.

## 2. Workspace / Management separation

### Workspace

Production entry `ObsGo.html` now routes to `ObsGo_Workspace.html`.

`ObsGo_Workspace.html` loads preserved source `ObsGo_Legacy_v7.html` and applies a fail-closed Workspace adapter before source execution.

Workspace corrections:
- Team Progress panel removed.
- `canSeeManage()` is hard-disabled inside Workspace, so Owner identity cannot switch normal History/Records into Team scope.
- Management team fetch is disabled in Workspace bootstrap.
- normal History remains My Records only.
- old role-conditioned `我的 / 全部人` Team path is unreachable in Workspace.
- Settings/Diagnostics role surface is removed from Workspace nav.
- Sync action remains available without opening Management.
- copy changed from management-surveillance wording to work wording: coverage of the whole class can be completed over multiple visits; not selected ≠ low score.
- authoritative ownership read/write is patched to immutable `created_by_uid` / auth UID.
- Workspace adapter checks required source + patched markers and FAILS CLOSED if the preserved v7 source changes unexpectedly.

Preserved immutable legacy source:
- `ObsGo_Legacy_v7.html`
- blob: `63d486b48d3b3c99c9e6e96de108bb2e68e21d8a`

### Management

Separate `ObsGo_Management.html` exists.

Access gate: OWNER / TOP_MGMT / ADMIN only.

Management is read-only against ObsGo source records and contains:
- Work Progress
- All Observations
- team Analysis
- Integration status

`Missing / Overdue` is explicitly **unsupported** because ObsGo currently has no authoritative Expected Work / due-date contract. The system does not fabricate expected visit counts or overdue semantics.

Authorized roles get a separate `Management` entry; ordinary Workspace users do not.

## 3. Production security / ownership migration

Production project: `Academee-Main` (`qnpvqsvvsgsantekgfbz`).

Applied migration:
- `obsgo_workspace_management_rls_and_output_plug_v1b`
- `obsgo_visit_updated_at_trigger_v1`

Changes:
- added `obsgo_visit.created_by_uid uuid references auth.users(id)`;
- safe legacy backfill only where display_name maps to exactly one users_meta user;
- default new ownership = `auth.uid()`;
- all 4 current ObsGo visits mapped unambiguously: AT → Owner UID, TAY → Teacher UID;
- added `updated_at` to child evidence tables;
- update triggers propagate correction timestamps;
- private management helper `private.obsgo_is_management()` with fixed search_path;
- no DELETE grant/policy;
- ordinary user SELECT = own visit only;
- management SELECT = team visits allowed;
- INSERT / UPDATE = own visit only;
- child rows inherit access through parent visit.

Current production policies verified:
- Visit: SELECT own-or-management / INSERT own / UPDATE own.
- Student entries: SELECT own-or-management / INSERT own / UPDATE own.
- Class entries: SELECT own-or-management / INSERT own / UPDATE own.

## 4. ObsGo Evidence Output Plug v1

Production adapter:

`public.v_obsgo_evidence_output_v1`

Properties:
- `security_invoker = true`
- SELECT only
- `is_updatable = NO`
- `is_insertable_into = NO`
- draft excluded completely
- completed emitted as `is_authoritative = true`
- cancelled emitted as `is_authoritative = false` invalidation signal, preserving source provenance
- missing actor ownership fails closed because rows require `created_by_uid is not null`
- source_record_id + source_visit_id preserved
- unsupported version concepts remain NULL rather than fabricated
- no source mutation from the plug

Shape currently exposes:
- contract_version
- source_system
- source_record_id
- source_visit_id
- schema_version (NULL / unsupported)
- student_id
- department
- programme (NULL / unsupported)
- class_id
- actor_id
- actor_role (NULL / unsupported)
- occurred_at (NULL / unsupported)
- occurred_on
- evidence_type
- evidence_code
- evidence_payload
- status
- taxonomy_version / rubric_version / mapping_version (NULL / unsupported)
- created_at / updated_at
- supersedes / superseded_by (NULL / unsupported; ObsGo has no such state)
- is_authoritative
- void_reason

No reopen / supersede semantics were invented because ObsGo authoritative states remain only:
`draft / completed / cancelled`.

## 5. Isolated contract/security test project

Test project: `LoveGo-Test-20260911` (`ebxcnxcmqmguqohbmjgj`) restored and used as isolated security test environment.

Test fixture:
- ordinary Observer A
- ordinary Observer B
- Owner
- one ATC class
- two students
- A draft
- A completed
- B completed
- B cancelled
- student + class evidence rows

RLS visibility probe results:

| Actor | Visits visible | Student rows | Class rows | Plug rows | Draft rows leaked |
|---|---:|---:|---:|---:|---:|
| Observer A | 2 | 2 | 1 | 2 | 0 |
| Observer B | 2 | 2 | 1 | 3 | 0 |
| Owner | 4 | 4 | 2 | 5 | 0 |

Result:
- ordinary A cannot read B records;
- ordinary B cannot read A records;
- Owner management can read permitted team records;
- plug inherits RLS;
- draft isolation PASS.

Correction propagation test:
- completed source evidence value changed from `S` to `D`;
- child `updated_at` changed;
- plug immediately returned `D` and the same newer timestamp.
- PASS.

Cancelled propagation test:
- cancelled source stays visible in plug;
- `status=cancelled`;
- `is_authoritative=false`;
- void reason preserved;
- downstream can invalidate stale evidence rather than silently retaining it.

Contract truth test:
- draft rows = 0;
- missing required provenance rows = 0;
- fabricated version rows = 0;
- plug is non-updatable / non-insertable.

## 6. Regression items preserved

Do not regress:
- draft / completed / cancelled distinction;
- Save / Resume / Exit;
- own draft cloud restore;
- no-delete / void model;
- completed-only authoritative evidence;
- student_id UUID identity;
- class-id healing fail closed;
- duplicate natural-key protection;
- Evidence / Support→Response / Shared Interpretation;
- SRK / SRT / ATC / GAK academic dictionaries.

## 7. Remaining gate before ObsGo LOCK

One final gate remains: **authenticated live-session browser regression** with a real ordinary ObsGo user and an authorized management user.

Required final checks:
1. ordinary user opens production ObsGo → normal Workspace only;
2. Owner opens production ObsGo → same normal Workspace flow plus separate Management entry only;
3. My Records contains own data only;
4. ordinary direct Management URL → denied;
5. Owner Management URL → PASS and team data visible;
6. Save / Resume / Exit / Complete / Void smoke test;
7. source edit/status change remains reflected in plug.

Backend/security/plug tests have passed; this final UI session cannot be truthfully claimed without an authenticated browser session.

## 8. Separate production security finding discovered during closeout

Supabase Security Advisor currently reports exposed public backup tables with RLS disabled. This is outside the ObsGo schema but is a real production security Owner boundary because changing backup-table access can affect recovery workflows.

Do not silently remediate without Owner decision.
