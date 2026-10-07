# Setup status — 2026-10-07

Completed:

- Local Git repository on main, initial commit `80abd82`.
- Annotated tag `v0.0.1-plan` for architecture/build infrastructure, pushed to GitHub.
- Private [tinyredphoenix/Cloudified](https://github.com/tinyredphoenix/Cloudified)
  created; origin connected; main pushed and tracking origin/main.
- Runtime, reliability, status, research and build contracts committed.
- Manual hosted-Xcode workflow and unsigned-IPA packaging script prepared.
- Markdown targets, shell syntax, workflow YAML and missing-project guard checked.
- Existing USB drive/data unchanged; no full local Xcode installation/download.

Resolved repository blocker:

- Earlier private-repository creation attempts failed repeatedly.
- CLI authentication and user lookup succeeded. GraphQL returned server failures;
  explicit REST creation returned HTTP 500 with an empty body.
- A later authenticated CLI retry succeeded. The repository, main history and
  planning tag now exist remotely. No browser login or credential replacement
  was needed.

Normal publishing for future verified batches:

```sh
git push origin main
git push origin --tags
```

Do not recreate the repository or rewrite published history/tags. No cloud build
was dispatched during repository setup; the workflow remains manual.

Not implemented yet: iOS app target, shared Xcode scheme, provider integration,
runtime cleanup and physical-device acceptance tests. The manual build workflow
deliberately stops before its macOS job until a real app project is present.
