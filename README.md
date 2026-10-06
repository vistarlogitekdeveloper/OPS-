# opsapp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Usage analytics (event tracker)

`lib/core/telemetry/telemetry.dart`, using the in-house `vistar_event_tracker`
SDK (vendored in `packages/`, see its `VENDORED.md`). Read in the Platform
Console under Analytics > Event tracker.

**Off unless the build gets both `ET_APP_ID` and `ET_WRITE_KEY`**; without them
nothing is initialised and the app behaves exactly as before. To switch it on:

1. Register `ops_app` in the Platform Console, Settings > Event tracker, and
   copy its write key.
2. Web (Cloudflare Workers Builds, project `ops`, build command
   `bash tool/cloudflare-build.sh`): add the build variables `ET_APP_ID=ops_app`
   and `ET_WRITE_KEY` (as a secret) under Settings > Build > Variables and
   secrets, pasted with no leading space or newline, then redeploy. The script
   passes the two defines only when both are set. (If the dashboard's build
   command is ever replaced by an inline `flutter build web`, append
   ` --dart-define=ET_APP_ID=$ET_APP_ID --dart-define=ET_WRITE_KEY=$ET_WRITE_KEY`
   to it.)
3. APK: `flutter build apk --release --dart-define=ET_APP_ID=ops_app --dart-define=ET_WRITE_KEY=wk_...`

Events go to the host of the backend the app starts on (a UAT build reports to
UAT); `ET_BASE_URL` overrides it.

Sent: screen views by route pattern (ids replaced: `/review/:id`,
`/sites/:id`), sign-in / sign-out (the user as `ops:<id>` with their role),
named actions from successful writes (`report_uploaded`, `submission_filed`,
`submission_reviewed`, `item_scored`, `project_created`, ... see `_actions`),
failed API calls (5xx / no connection) and client errors by type. Never sent:
request or response bodies, names, usernames, emails, phone numbers, site
names or codes, file names, marks, remarks or comments. Nothing is awaited by
a screen, an upload, a sign-in or a sign-out; start-up waits at most 2 s; the
event queue is capped at 200.
