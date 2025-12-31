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
  const inviteId = String.fromEnvironment(
    'MYAPPCREW_INVITE_ID',
    defaultValue: '',
  );

  final result = await MyAppCrew.initialize(
    publicKey: publicKey,
    baseUrl: baseUrl,
    inviteId: inviteId.isEmpty ? null : inviteId,
  );

  runApp(
    MyAppCrewExampleApp(
      initOk: result.ok,
      baseUrl: baseUrl,
      publicKey: publicKey,
    ),
  );
}

class MyAppCrewExampleApp extends StatelessWidget {
  const MyAppCrewExampleApp({
    super.key,
    required this.initOk,
    required this.baseUrl,
    required this.publicKey,
  });

  final bool initOk;
  final String baseUrl;
  final String publicKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyAppCrew Example',
      navigatorObservers: [MyAppCrew.navigatorObserver()],
      routes: <String, WidgetBuilder>{
        '/': (_) => HomeScreen(
              initOk: initOk,
              baseUrl: baseUrl,
              publicKey: publicKey,
            ),
        '/profile': (_) => const ProfileScreen(),
        '/checkout': (_) => const CheckoutScreen(),
      },
      initialRoute: '/',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.initOk,
    required this.baseUrl,
    required this.publicKey,
  });

  final bool initOk;
  final String baseUrl;
  final String publicKey;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _inviteController = TextEditingController();
  String? _testerId;
  String? _sessionId;
  Map<String, dynamic>? _snapshot;
  bool _initOk = false;

  @override
  void initState() {
    super.initState();
    _initOk = widget.initOk;
    _refreshIds();
    _refreshSnapshot();
  }

  void _refreshIds() {
    setState(() {
      _testerId = MyAppCrew.testerId;
      _sessionId = MyAppCrew.sessionId;
    });
  }

  Future<void> _refreshSnapshot() async {
    final snapshot = await MyAppCrew.debugSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
    });
  }

  Future<void> _claimInvite() async {
    final inviteId = _inviteController.text.trim();
    if (inviteId.isEmpty) {
      return;
    }
    final result = await MyAppCrew.initialize(
      publicKey: widget.publicKey,
      baseUrl: widget.baseUrl,
      inviteId: inviteId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _initOk = result.ok;
    });
    _refreshIds();
    _refreshSnapshot();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text('Initialized: ${_initOk ? 'yes' : 'no'}'),
          const SizedBox(height: 8),
          Text('Tester ID: ${_testerId ?? '-'}'),
          Text('Session ID: ${_sessionId ?? '-'}'),
          const SizedBox(height: 16),
          TextField(
            controller: _inviteController,
            decoration: const InputDecoration(
              labelText: 'Invite ID (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _claimInvite,
            child: const Text('Claim Invite'),
          ),
          const SizedBox(height: 16),
          if (snapshot != null) ...<Widget>[
            const Text('Snapshot'),
            const SizedBox(height: 8),
            Text('Base URL: ${snapshot['baseUrl'] ?? '-'}'),
            Text('Public Key: ${snapshot['publicKey'] ?? '-'}'),
            Text('Tester ID: ${snapshot['testerId'] ?? '-'}'),
            Text('Has Token: ${snapshot['hasToken'] ?? '-'}'),
            Text('Ingest URL: ${snapshot['ingestUrl'] ?? '-'}'),
            Text('Last Error: ${snapshot['lastError'] ?? '-'}'),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: () {
              MyAppCrew.logEvent('home_cta', properties: {
                'label': 'Get Started',
              });
              _refreshIds();
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
                await MyAppCrew.flushNow();
                _refreshIds();
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
