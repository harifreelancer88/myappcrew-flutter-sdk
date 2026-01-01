# MyAppCrew Flutter SDK

Headless SDK for bootstrapping testers, tracking lifecycle/screen events, and batching events.

## Minimal install (dependency + init)

1) Add dependency:

```sh
flutter pub add myappcrew_flutter
```

2) Initialize once in `main.dart`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MyAppCrewFlutter.init(publicKey: 'YOUR_PUBLIC_KEY');

  runApp(const MyApp());
}
```

Notes:
- `baseUrl` is optional and defaults to `https://myappcrew-tw.pages.dev`.
- If `publicKey` is missing, the SDK disables itself (no network calls).

## Optional: screen tracking (navigator observer)

Add the navigator observer when you want screen tracking:

```dart
final observer = MyAppCrewFlutter.navigatorObserver();

MaterialApp(
  navigatorObservers: observer == null ? const [] : [observer],
  home: const MyHomePage(),
);
```

## Optional: manual connect (claim link or token)

1) Tester joins the invite in a browser.
2) Copy the claim token or full claim link.
3) In-app, call `connectFromText(...)` (token or URL both work):

```dart
ElevatedButton(
  onPressed: () async {
    final result = await MyAppCrewFlutter.connectFromText(inputText);
    if (result.connected) {
      // Connected
    }
  },
  child: const Text('Connect tester'),
);
```

## Debugging (safe snapshot + logging)

Read a safe snapshot that excludes secrets:

```dart
final snapshot = MyAppCrewFlutter.getDebugSnapshot();
```

Enable SDK logging explicitly (off by default):

```dart
MyAppCrewFlutter.setDebugLogging(true);
```

You can also enable logging at compile time:

```sh
flutter run --dart-define=MYAPPCREW_DEBUG_LOGS=true
```
