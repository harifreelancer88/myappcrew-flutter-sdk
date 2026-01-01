# Changelog

## 0.1.3
- Simplified owner-facing `MyAppCrewFlutter` API with one-step `init`.
- Disabled mode when `publicKey` is missing (no network calls).
- Manual connect via claim token or link with a single 401 rebootstrap retry.
- Safer debug snapshot plus lifecycle events and optional navigator observer.

## 0.1.2
- Documentation and metadata touch-ups.
- No runtime behavior changes.

## 0.1.1
- Added example app.
- Added pub.dev metadata (repository/issue tracker/topics).
- Improved README quickstart.
- Formatting-only changes; no runtime behavior changes.

## 0.1.0
- Bootstrap with access token persistence.
- Batched event flush with retries and single rebootstrap on 401.
- `screen_view` auto-tracking via `navigatorObserver`.
- Lifecycle-based flush triggers.
- Server-provided `ingestUrl` used for batch endpoint.
