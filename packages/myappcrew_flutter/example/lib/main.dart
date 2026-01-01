import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const publicKey = String.fromEnvironment(
    'MYAPPCREW_PUBLIC_KEY',
    defaultValue: 'com.test_app.test',
  );
  const baseUrl = String.fromEnvironment(
    'MYAPPCREW_BASE_URL',
    defaultValue: 'https://myappcrew-tw.pages.dev',
  );

  await MyAppCrewFlutter.init(
    publicKey: publicKey,
    baseUrl: baseUrl,
  );

  runApp(const MyAppCrewExampleApp());
}

class MyAppCrewExampleApp extends StatelessWidget {
  const MyAppCrewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAppCrew Example',
      navigatorObservers: [MyAppCrewFlutter.navigatorObserver],
      routes: <String, WidgetBuilder>{
        '/': (_) => const HomeScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/checkout': (_) => const CheckoutScreen(),
      },
      initialRoute: '/',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _snapshot;

  @override
  void initState() {
    super.initState();
    _refreshSnapshot();
  }

  void _refreshSnapshot() {
    setState(() {
      _snapshot = MyAppCrewFlutter.debugSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Initialized: ${MyAppCrewFlutter.isInitialized ? 'yes' : 'no'}'),
          Text('Enabled: ${MyAppCrewFlutter.isEnabled ? 'yes' : 'no'}'),
          const SizedBox(height: 16),
          if (snapshot != null) ...<Widget>[
            const Text('Snapshot'),
            const SizedBox(height: 8),
            Text('Public Key Suffix: ${snapshot['publicKeySuffix'] ?? '-'}'),
            Text('Tester ID: ${snapshot['testerId'] ?? '-'}'),
            Text('Ingest URL: ${snapshot['ingestUrl'] ?? '-'}'),
            Text('Last Error: ${snapshot['lastError'] ?? '-'}'),
            Text('Last Bootstrap: ${snapshot['lastBootstrapAt'] ?? '-'}'),
            Text('Last Flush: ${snapshot['lastFlushAt'] ?? '-'}'),
            Text('Queue Size: ${snapshot['queueSize'] ?? '-'}'),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: () {
              MyAppCrewFlutter.logEvent('home_cta', params: {
                'label': 'Get Started',
              });
              _refreshSnapshot();
            },
            child: const Text('Log Event'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/profile'),
            child: const Text('Go to Profile'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/checkout'),
            child: const Text('Go to Checkout'),
          ),
          if (kDebugMode)
            OutlinedButton(
              onPressed: () async {
                await MyAppCrewFlutter.flushNow();
                _refreshSnapshot();
              },
              child: const Text('Flush Now (debug)'),
            ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Profile screen'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                MyAppCrewFlutter.logEvent('profile_save');
              },
              child: const Text('Log Event'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Checkout screen'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                MyAppCrewFlutter.logEvent('checkout_submit');
              },
              child: const Text('Log Event'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
