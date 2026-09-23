import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/business_repository.dart';
import '../subscriptions/subscription_screen.dart';
import 'business_setup_screen.dart';

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() => _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final _repo = BusinessRepository(Supabase.instance.client);
  Map<String, dynamic>? _business;
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final business = await _repo.myBusiness();
      if (business != null) {
        _services = await _repo.services(business['user_id'] as String);
      }
      if (mounted) setState(() => _business = business);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load dashboard: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Business dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
              title: Text(_business?['business_name'] as String? ?? 'Business profile'),
              subtitle: Text(_business?['location_label'] as String? ?? 'Add your business location'),
              trailing: _business?['is_verified'] == true ? const Icon(Icons.verified) : const Icon(Icons.hourglass_empty),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _Stat(title: 'Services', value: '${_services.length}', icon: Icons.handyman_outlined),
              _Stat(title: 'Verified', value: _business?['is_verified'] == true ? 'Yes' : 'Pending', icon: Icons.verified_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit business profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
                    );
                    if (mounted) _load();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.credit_card_outlined),
                  title: const Text('Subscription'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Team members, invitations and group management are intentionally a next-stage module. The business account, listing, category, location and subscription foundation is ready.'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value, required this.icon});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon),
          Text(title),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
