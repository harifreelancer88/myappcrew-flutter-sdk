# MyAppCrew Flutter SDK

A tiny Flutter SDK to bootstrap tester sessions, queue events, auto-track screens, and flush batches safely.

## Install (pub.dev)

```sh
flutter pub add myappcrew_flutter
```

## Install (path dependency)

Option A: path dependency

```yaml
dependencies:
  myappcrew_flutter:
    path: ../myappcrew_flutter_sdk/packages/myappcrew_flutter
```

## Minimal usage

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final result = await MyAppCrew.initialize(
    publicKey: 'YOUR_PUBLIC_KEY',
    baseUrl: 'https://api.myappcrew.com',
  );

  runApp(
    MaterialApp(
      navigatorObservers: [
        MyAppCrew.navigatorObserver(),
      ],
      home: const MyHomePage(),
    ),
  );

  if (result.ok) {
    MyAppCrew.logEvent('button_click', properties: {
      'label': 'Subscribe',
    });
    await MyAppCrew.flushNow();
  }
}
```

## Invite claim usage

```dart
final result = await MyAppCrew.initialize(
  publicKey: 'YOUR_PUBLIC_KEY',
  baseUrl: 'https://api.myappcrew.com',
  inviteId: 'YOUR_INVITE_ID',
  nickname: 'Ada Lovelace',
  email: 'ada@example.com',
);
```

## Configuration via --dart-define

```sh
flutter run -d <device> \
  --dart-define=MYAPPCREW_BASE_URL=https://myappcrew-tw.pages.dev \
  --dart-define=MYAPPCREW_PUBLIC_KEY=com.test_app.test \
  --dart-define=MYAPPCREW_INVITE_ID=invite_123
```

## Data sent

- `name`
- `ts` (seconds)
- `screen`
- `sessionId`
- `properties`

## Notes

- `baseUrl` is required and must not assume localhost.
- `ingestUrl` comes from the bootstrap response and may change server-side.
- All event timestamps use UNIX seconds (10-digit).
- Retries use small backoff; no infinite loops.
- SDK is best-effort and should not crash the host app.

## Example app

An example app is available under `example/`.

```sh
cd example
flutter pub get
flutter run -d <device> \
  --dart-define=MYAPPCREW_BASE_URL=https://myappcrew-tw.pages.dev \
  --dart-define=MYAPPCREW_PUBLIC_KEY=com.test_app.test
```
