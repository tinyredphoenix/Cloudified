# Builder workflow

1. Read the assigned contract/batch and identify critical files to change.
2. Implement one coherent batch without mixing UI polish and protocol changes.
3. Use static review and necessary syntax/compiler checks during implementation.
   Do not run intermediate app test suites or per-phase cloud builds. First assemble
   every feature, then build/test the complete app at P7 and debug real failures.
4. Report objective, changed paths, dependency revisions, focused diff, exact check
   results, screenshots where useful, and unresolved issues. Do not equate a passing
   build with successful Google quota behavior or background-device behavior.
5. Architect reviews important auth/protocol/export/ledger/cleanup/lifecycle changes
   directly. Routine UI changes can use summaries and screenshots.
6. Commit the verified batch; push main and any annotated milestone tags. Never
   amend published milestones or tag an unverified feature as working.

First Builder application batch is P1 in docs/02-BUILD-PHASES.md: target/shared
scheme and genuine disconnected/unavailable dashboard states. No demo/mock data.
Critical P2 engine is directly
authored by the Architect. Provider pinning/integration belongs to later assigned
batches. Until a real project exists, cloud build stops at lightweight preflight.

UI is purpose-built for upload status, failures, logs and account settings. Do not
copy reference app screens or add a gallery. No expensive UI-inspiration research
is required for this project.
