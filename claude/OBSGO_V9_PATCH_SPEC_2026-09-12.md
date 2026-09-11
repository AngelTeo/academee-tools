ObsGo v9 patch specification

1. Workspace lifecycle
- Change button label from 开始巡班 to 进入巡班.
- Entering a class creates only an ephemeral in-memory visit.
- Do not add it to state.drafts and do not save it on entry.
- On first meaningful input (visit note, student selection, class rating/evidence/note), promote the visit to a real draft.
- At promotion time set startedAt=nowHM(), startedTs=Date.now(), then add to state.drafts.
- Empty browse-only visit must leave no local/cloud draft and no unfinished record.
- Existing real drafts remain resumable.

2. Management bootstrap
- Use the existing authenticated session user id from getSession() for the role lookup instead of making a second getUser() request.
- Add a 10-second fail-closed timeout so Management cannot remain forever on 正在确认 Management 权限.
- Unauthorized roles remain denied.

Owner approved 2026-09-12.