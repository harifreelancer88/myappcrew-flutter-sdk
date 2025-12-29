import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const baseUrl = String.fromEnvironment(
    'MYAPPCREW_BASE_URL',
    defaultValue: 'https://myappcrew-tw.pages.dev',
  );
  const publicKey = String.fromEnvironment(
    'MYAPPCREW_PUBLIC_KEY',
    defaultValue: 'com.test_app.test',
  );

  final result = await MyAppCrew.initialize(
    publicKey: publicKey,
    baseUrl: baseUrl,
  );

  runApp(MyAppCrewExampleApp(initOk: result.ok));
}

class MyAppCrewExampleApp extends StatelessWidget {
  const MyAppCrewExampleApp({super.key, required this.initOk});

  final bool initOk;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAppCrew Example',
      navigatorObservers: [MyAppCrew.navigatorObserver()],
      routes: <String, WidgetBuilder>{
        '/': (_) => HomeScreen(initOk: initOk),
        '/profile': (_) => const ProfileScreen(),
        '/checkout': (_) => const CheckoutScreen(),
      },
      initialRoute: '/',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.initOk});

  final bool initOk;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _testerId;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _refreshIds();
  }

  void _refreshIds() {
    setState(() {
      _testerId = MyAppCrew.testerId;
      _sessionId = MyAppCrew.sessionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Initialized: ${widget.initOk ? 'yes' : 'no'}'),
          const SizedBox(height: 8),
          Text('Tester ID: ${_testerId ?? '-'}'),
          Text('Session ID: ${_sessionId ?? '-'}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              MyAppCrew.logEvent('home_cta', properties: {
                'label': 'Get Started',
              });
              _refreshIds();
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
                await MyAppCrew.flushNow();
                _refreshIds();
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
                MyAppCrew.logEvent('profile_save');
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
                MyAppCrew.logEvent('checkout_submit');
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
