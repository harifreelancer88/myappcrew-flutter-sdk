# MyAppCrew Flutter SDK

A tiny Flutter SDK to bootstrap tester sessions, queue events, auto-track screens, and flush batches safely.

## Install (path dependency)

Option A: path dependency

```yaml
dependencies:
  myappcrew_flutter:
    path: ../myappcrew_flutter_sdk/packages/myappcrew_flutter
```

## Initialize

```dart
final result = await MyAppCrew.initialize(
  publicKey: 'YOUR_PUBLIC_KEY',
  baseUrl: 'https://api.myappcrew.com',
);
```

## Auto screen tracking

```dart
MaterialApp(
  navigatorObservers: [
    MyAppCrew.navigatorObserver(),
  ],
);
```

## Log events

```dart
MyAppCrew.logEvent('button_click', properties: {
  'label': 'Subscribe',
});
```

## Notes

- `baseUrl` is required and must not assume localhost.
- `ingestUrl` comes from the bootstrap response and may change server-side.
- All event timestamps use UNIX seconds (10-digit).
- Retries use small backoff; no infinite loops.
- SDK is best-effort and should not crash the host app.
