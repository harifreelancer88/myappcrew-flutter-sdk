# Changelog

## 0.1.10
- Persist connected tester identity across app restarts and attach it to events.
- Add invalid identity handling with a reconnect callback.
- Add tester identity API helpers.

## 0.1.9
- Fix connect prompt red flash (Overlay ancestor fix).

## 0.1.8
- Fix connect prompt keyboard overlap and remove submit error flash.

## 0.1.7
- Add debug-only connect prompt overlay widget.

## 0.1.6
- Optional connect code UI wrapper (debug-only default) for auto prompt.

## 0.1.5
- Added 6-digit Connect Code support in connect parsing and claim calls.
- Added last connect input kind to debug snapshot and connect results.

## 0.1.4
- Added safe `DebugSnapshot` API for headless debugging.
- Added debug logging toggle (off by default).
- Added `connectFromText` typed result details and optional navigator observer accessor.
- No breaking changes.

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
