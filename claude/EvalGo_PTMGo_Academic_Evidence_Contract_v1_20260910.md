# EvalGo → PTMGo · Academic Evidence Contract v1

Date: 2026-09-10 MYT
Status: DESIGN CONTRACT · no production change

## 1. Boundary

EvalGo is an Academic Evidence Source for PTMGo.

EvalGo owns raw exam-cycle evidence. PTMGo must not infer or rewrite the source identity of that evidence.

Canonical provenance path:

`student_id -> exam_id -> paper_instance_id -> evidence row -> subject summary -> PTMGo`

`Academee student_id` remains the student identity anchor.

## 2. What PTMGo should consume

PTMGo should not directly depend on EvalGo's transient local UI state.

It should consume a cloud-derived academic package with:

- `student_id`
- `exam_id`
- `subject`
- `subject_summary`
- `paper_evidence[]`
- readiness / completeness state
- provenance references
- generated/snapshot timestamp

## 3. Paper evidence item

Each paper evidence item should expose at minimum:

- `paper_instance_id`
- paper label / display number
- paper date if available
- source teacher(s)
- completion state
- paper checked state
- TP / mastery outcome where applicable
- weakness evidence
- next/fix evidence
- section-level evidence references
- wrong-item evidence references
- essay evidence references

PTMGo should display or summarize this evidence but must retain the `paper_instance_id` provenance internally.

## 4. Subject summary

A subject summary is not the same object as one Paper Analysis row.

Future rule:

`Subject Summary = deterministic/approved aggregation of one or more Paper Instances`

It may include:

- overall mastery / TP
- repeated weakness patterns across papers
- improvement or regression between papers
- evidence-backed next steps
- parent support suggestion
- report-ready state

The summary must be regenerable from authoritative evidence and must not destroy paper-level history.

## 5. September 2026 compatibility

For the current September report only, v25's existing one-row `evalgo_paper_analysis` subject behavior remains the report source.

This is a compatibility layer, not the permanent PTMGo contract.

After multi-paper release:

- legacy September rows map to Legacy Paper Instances;
- later Paper Instances coexist without overwriting them;
- PTMGo aggregation can consume both legacy and new paper-level evidence.

## 6. Evidence immutability and snapshots

PTMGo should store/report references or snapshots, not silently mutate EvalGo evidence.

Recommended separation:

- authoritative EvalGo row remains in EvalGo tables;
- PTMGo stores a report-cycle snapshot/reference containing the source IDs and source version/timestamp;
- later EvalGo edits do not retroactively rewrite an already-issued parent report unless explicitly regenerated.

## 7. Readiness gate

PTMGo must not treat partial EvalGo evidence as complete simply because rows exist.

For the current September compatibility path, use existing report readiness semantics.

Future multi-paper readiness should be explicit at two levels:

- Paper Ready
- Subject Ready for PTMGo

A subject may require one or more active Papers depending on the report cycle configuration.

## 8. Ownership

- EvalGo owns exam evidence capture and paper provenance.
- ParentGo/PTMGo owns parent-facing synthesis and presentation.
- Academee owns Student Master identity.
- AI may summarize evidence but does not invent student facts or change source ownership.

## 9. Required future API/view shape

Target read model:

```json
{
  "student_id": "...",
  "exam_id": "...",
  "subject": "...",
  "subject_ready": true,
  "subject_summary": {
    "tp": "...",
    "weaknesses": [],
    "next_steps": [],
    "parent_support": "..."
  },
  "papers": [
    {
      "paper_instance_id": "...",
      "label": "...",
      "ready": true,
      "evidence_refs": {
        "analysis_id": "...",
        "live_obs_ids": [],
        "wrong_item_ids": [],
        "essay_result_ids": []
      }
    }
  ],
  "snapshot_at": "..."
}
```

The exact transport mechanism may be a view, RPC, or service layer later; the data contract above is canonical.

## 10. Non-negotiable rules

1. PTMGo must never identify a paper only by free-text label.
2. Paper provenance uses `paper_instance_id`.
3. Student identity uses Academee `student_id`.
4. Subject summary must not overwrite paper evidence.
5. Issued reports need snapshot/reference traceability.
6. Missing/partial evidence must remain visibly incomplete.
