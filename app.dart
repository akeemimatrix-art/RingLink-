import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/shell/main_shell.dart';

class RingLinkApp extends StatelessWidget {
  const RingLinkApp({super.key, this.configurationError = false});

  final bool configurationError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RingLink',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: configurationError
          ? const _ConfigurationErrorScreen()
          : const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _session = Supabase.instance.client.auth.currentSession;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (mounted) setState(() => _session = state.session);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _session == null ? const AuthScreen() : const MainShell();
  }
}

class _ConfigurationErrorScreen extends StatelessWidget {
  const _ConfigurationErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, size: 64),
                const SizedBox(height: 20),
                Text(
                  'RingLink is not configured',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Copy config/dev.example.json to config/dev.json, add your Supabase URL and publishable key, then run with --dart-define-from-file=config/dev.json.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
