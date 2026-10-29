# Phase 10 release-candidate validation

Current audit (2026-10-29): the release remains **NOT APPROVED**. Billing provider verification/recovery, encrypted backup/restore and the deletion worker are missing implementations; deletion and conversation attachment uploads remain disabled. The development database has thirteen migrations including integrity repairs. See [the current gap analysis](release-readiness-gap-analysis.md) for actual evidence and prerequisites. Source SQL parsing and local tests do not establish hosted RLS, concurrency, provider or device acceptance.

Phase 10 validates the integrated BakeQuote release candidate. It does not
replace hosted acceptance, provider verification, native-device testing, or
operator recovery evidence.

## Reproducible local gate

From `mobile`:

```powershell
python scripts/release_candidate.py
```

Optional build gates:

```powershell
python scripts/release_candidate.py --build-web --build-apk
```

The command runs Dart formatting, Flutter analysis, the complete Flutter test
suite, SQL migration parsing, and a configuration safety scan. It writes
`release-candidate-report.json`; that generated report is local evidence and
must not contain credentials. A non-zero exit code means the local candidate
cannot proceed.

## Acceptance matrix

| Area | Local gate | Hosted/device evidence | Status |
| --- | --- | --- | --- |
| Customer request and estimate | Flutter tests, SQL parsing | Two-account request/quote/submit | BLOCKED |
| Baker operations | Flutter tests, SQL parsing | Hosted capacity/concurrency | BLOCKED |
| Communication/moderation | Flutter tests, SQL parsing | Two-account messaging/RLS/media | BLOCKED |
| Synchronization | Flutter tests, SQL parsing | Lost response/stale version/second device | BLOCKED |
| Billing | Entitlement schema and locked callback contract | Apple/Google sandbox verification | BLOCKED |
| Backup/restore | Snapshot contract only | Encrypted archive/media restore rehearsal | BLOCKED |
| Deletion | Re-authenticated request and job records | Worker/Auth/media cleanup rehearsal | BLOCKED |
| Security regression | Config scan and restricted SQL grants | Hosted forged-ID/RLS/storage probes | BLOCKED |
| Performance | Local test/build gates | B26 volumes and target devices | DEFERRED |
| Android/iOS acceptance | Optional compile gates | Installed devices, callbacks, permissions | DEFERRED |

`BLOCKED` means required evidence is unavailable, not that the workflow
passed. `DEFERRED` means the environment or hardware was not exercised.
Neither status permits a production release.

## Release decision

The current candidate is **NOT APPROVED**. Local implementation and
regression gates can pass while the release remains blocked by missing
hosted accounts, provider credentials, deletion workers, encrypted
backup/restore verification, and native devices. The exact external setup is
documented in [backend setup](backend-setup.md) and
[integration verification](integration-verification.md).

Before approval, attach the generated report plus sanitized evidence for
AT01–AT24, database/storage security probes, performance measurements,
provider reconciliation, backup/restore recovery, deletion-job recovery, and
the Android/iOS device matrix.
