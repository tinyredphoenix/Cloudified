# Builder workflow

1. Read the assigned contract/batch and identify critical files to change.
2. Implement one coherent batch without mixing UI polish and protocol changes.
3. Run checks appropriate to the change. Critical state-machine/receipt/recovery
   behavior requires meaningful failure tests; device behavior requires device evidence.
4. Report objective, changed paths, dependency revisions, focused diff, exact check
   results, screenshots where useful, and unresolved issues. Do not equate a passing
   build with successful Google quota behavior or background-device behavior.
5. Architect reviews important auth/protocol/export/ledger/cleanup/lifecycle changes
   directly. Routine UI changes can use summaries and screenshots.
6. Commit the verified batch; push main and any annotated milestone tags. Never
   amend published milestones or tag an unverified feature as working.

First application batch: pin Google/TDLib dependencies, create the iOS target/shared
scheme, validate original resource export and provider authentication, then prove
the new integration's behavior on the signed iPhone. Until a real project exists,
the cloud iOS build intentionally fails at its lightweight preflight.

UI is purpose-built for upload status, failures, logs and account settings. Do not
copy reference app screens or add a gallery. No expensive UI-inspiration research
is required for this project.
