# EvalGo_ATC · Controlled Delete Contract v1

Date: 2026-09-10 MYT
Status: POST-REPORT BUILD CONTRACT · no production change

## 1. Purpose

Permanent deletion is allowed only as an explicit management action. Database cascade is not accepted as the normal deletion mechanism for student evidence.

The system must preserve three properties:

1. the user knows exactly how much data will be destroyed;
2. a complete machine-readable backup exists before destructive writes begin;
3. every DELETE is verified by returned affected rows, not merely by absence of an exception.

## 2. Authorization

Use existing `CLOUD.perm.can_approve` as the single delete-authority source.

Do not introduce a second role map.

- `can_approve !== true`: destructive cloud delete controls are hidden/disabled.
- `can_approve === true`: destructive delete controls may be shown.

## 3. Section delete

### 3.1 Evidence count

For one `evalgo_paper_section`, count at minimum:

- `evalgo_wrong_item` where `section_id = section.id`
- `evalgo_essay_result` where `section_id = section.id`

After Paper Instance release, section membership must be validated against `paper_instance_id` as well.

### 3.2 No evidence

Flow:

1. request delete;
2. cloud `.delete().eq('id', section_id).select()`;
3. PASS only when exactly one section row is returned;
4. only then remove local state / repaint UI;
5. zero rows = failure; keep local state and show an explicit message.

### 3.3 Evidence exists

Flow:

1. read the section and all dependent evidence;
2. calculate distinct-student count and total-row count;
3. show destructive warning with exact counts;
4. on confirmation, build the backup object;
5. trigger browser download;
6. if download cannot be initiated, cancel the delete before any DB DELETE;
7. delete child evidence explicitly, table by table, using `.delete().select()`;
8. verify returned row count against the pre-delete snapshot count for each child table;
9. if any child count mismatches, stop. Do not delete the parent section;
10. delete the section last with `.delete().select()`;
11. require exactly one returned section row;
12. final SELECT confirms the section no longer exists;
13. only after cloud verification update local state / UI.

## 4. Backup format

Filename:

`EvalGo_Delete_Backup_<exam>_<subject>_<paper>_<section>_<YYYYMMDD_HHMMSS>.json`

Required document shape:

```json
{
  "_meta": {
    "deleted_at_myt": "...",
    "deleted_by": "...",
    "app_version": "...",
    "reason": "user_confirmed_delete"
  },
  "paper_instance": {},
  "paper_section": {},
  "wrong_item": [],
  "essay_result": []
}
```

Do not trim DB fields. Preserve IDs, `client_uid`, timestamps, provenance and all payload fields.

For whole-paper delete the backup must additionally include all paper sections and all paper-level evidence tables.

## 5. Whole-paper delete

Before deleting one `evalgo_paper_instance`, enumerate and show:

- number of scoped classes;
- number of linked teachers;
- number of sections;
- distinct students affected;
- `live_obs` rows;
- `paper_analysis` rows;
- `wrong_item` rows;
- `essay_result` rows.

Then use the same backup-first and verified child-to-parent deletion flow.

No `ON DELETE CASCADE` from `evalgo_paper_instance` to evidence is permitted.

## 6. RLS zero-row rule

Supabase/PostgREST can return a successful request with zero deleted rows when RLS prevents the target row from being visible/deletable.

Therefore this is prohibited:

`if (!error) { treat as deleted }`

Required semantics:

- `error` present -> FAIL
- `data.length === 0` -> FAIL
- expected row count != returned row count -> FAIL
- only exact affected-row match -> PASS

Suggested user-facing failure:

> 删除没有成功。云端资料仍然保留，请找管理层检查权限或资料状态。

## 7. FK policy

Target state:

- `paper_instance` -> child relations: `RESTRICT` / `NO ACTION`
- `paper_section` -> `wrong_item`: `RESTRICT`
- `paper_section` -> `essay_result`: `RESTRICT`

This is deliberate. The database is the final guard against accidental parent deletion before child evidence has been intentionally removed.

## 8. Regression gates

At minimum test:

1. delete controls absent for `can_approve=false`;
2. no-evidence section delete checks `.select()` returned row;
3. RLS zero-row response leaves local state unchanged;
4. evidence delete warns with exact counts;
5. backup failure performs zero DELETEs;
6. child delete count mismatch prevents parent delete;
7. section deleted only after all child validations pass;
8. final SELECT verifies absence;
9. whole-paper delete cannot bypass child enumeration;
10. no evidence FK from paper/section uses CASCADE.
