# MyAppCrew Flutter SDK

Tiny SDK for bootstrapping testers, tracking lifecycle/screen events, and batching events.

## 2-minute install (minimum)

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

## Optional: screen tracking

Add the navigator observer when you want screen tracking:

```dart
MaterialApp(
  navigatorObservers: [MyAppCrewFlutter.navigatorObserver],
  home: const MyHomePage(),
);
```

## Tester connect (no deep links)

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
