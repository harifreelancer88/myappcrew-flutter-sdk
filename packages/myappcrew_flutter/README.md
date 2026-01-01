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

## Optional: manual connect (claim link, token, or 6-digit code)

1) Tester joins the invite in a browser.
2) Copy the claim token, full claim link, or 6-digit Connect Code.
3) In-app, call `connectFromText(...)` (token, URL, or 6-digit code):

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

## Optional: connect prompt UI (debug-only by default)

Auto-prompt testers for the 6-digit Connect Code without extra app state.

Option A (recommended):

```dart
runApp(MyAppCrewConnectWrapper(
  child: const MyApp(),
));
```

Option B (MaterialApp builder):

```dart
MaterialApp(
  builder: (context, child) => MyAppCrewConnectWrapper(child: child!),
)
```

Notes:
- Debug builds only by default. Enable in release with
  `MyAppCrewConnectWrapper(enabled: true, ...)`.
- Testers enter the 6-digit Connect Code from the invite page.
- Once connected, they will not be prompted again unless the app is cleared or
  reinstalled (or the public key changes).

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
