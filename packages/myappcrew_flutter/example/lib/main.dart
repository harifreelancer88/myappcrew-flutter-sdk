import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const publicKey = String.fromEnvironment(
    'MYAPPCREW_PUBLIC_KEY',
    defaultValue: '',
  );

  await MyAppCrewFlutter.init(
    publicKey: publicKey.isEmpty ? null : publicKey,
  );

  runApp(
    MyAppCrewConnectWrapper(
      child: const MyAppCrewExampleApp(),
    ),
  );
}

class MyAppCrewExampleApp extends StatelessWidget {
  const MyAppCrewExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final observer = MyAppCrewFlutter.navigatorObserver();
    return MaterialApp(
      title: 'MyAppCrew Example',
      navigatorObservers: observer == null
          ? const <NavigatorObserver>[]
          : <NavigatorObserver>[observer],
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
  DebugSnapshot? _snapshot;
  final TextEditingController _claimController = TextEditingController();
  String? _connectMessage;

  @override
  void initState() {
    super.initState();
    _refreshSnapshot();
  }

  @override
  void dispose() {
    _claimController.dispose();
    super.dispose();
  }

  void _refreshSnapshot() {
    setState(() {
      _snapshot = MyAppCrewFlutter.getDebugSnapshot();
    });
  }

  Future<void> _connectFromText() async {
    final result =
        await MyAppCrewFlutter.connectFromText(_claimController.text);
    final snapshot = MyAppCrewFlutter.getDebugSnapshot();
    setState(() {
      _snapshot = snapshot;
      if (result.connected) {
        _connectMessage = 'Connected tester: ${result.testerId ?? '-'}';
      } else {
        _connectMessage =
            'Connect failed: ${result.errorCode ?? 'unknown_error'}';
      }
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
          const Text(
            'Example only / debug only',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (snapshot != null) ...<Widget>[
            Text('Snapshot initialized: ${snapshot.initialized ? 'yes' : 'no'}'),
            Text('Base URL: ${snapshot.baseUrl}'),
            Text(
              'Public Key Last 4: ${snapshot.publicKeyLast4.isEmpty ? '-' : snapshot.publicKeyLast4}',
            ),
            Text(
              'Tester ID: ${snapshot.testerId.isEmpty ? '-' : snapshot.testerId}',
            ),
            Text('Connected: ${snapshot.connected ? 'yes' : 'no'}'),
            Text('Last Error: ${snapshot.lastErrorCode ?? '-'}'),
            Text('Queue Size: ${snapshot.queuedEventsCount}'),
            Text(
              'Last Bootstrap: ${snapshot.lastBootstrapAt?.toIso8601String() ?? '-'}',
            ),
            Text(
              'Last Flush: ${snapshot.lastFlushAt?.toIso8601String() ?? '-'}',
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _claimController,
            decoration: const InputDecoration(
              labelText: 'Claim link or token',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _connectFromText,
            child: const Text('Connect from text'),
          ),
          if (_connectMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_connectMessage!),
          ],
          const SizedBox(height: 16),
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
