import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../auth/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Location permission'),
                  subtitle: const Text('Android controls whether RingLink can use your device location.'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => Geolocator.openAppSettings(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Security'),
                  subtitle: Text('Authentication is managed by Supabase Auth.'),
                ),
                const ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Privacy'),
                  subtitle: Text('Review your privacy policy and location/document permissions before launch.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
