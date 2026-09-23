import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/formatters.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = true;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Supabase.instance.client
          .from('subscriptions')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _subscriptions = List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load subscription: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request(String plan) async {
    setState(() => _requesting = true);
    try {
      final existing = await Supabase.instance.client
          .from('subscriptions')
          .select('id,status')
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .inFilter('status', ['active', 'pending'])
          .maybeSingle();
      if (existing != null) {
        throw Exception('You already have an active or pending subscription.');
      }
      final price = plan == 'business' ? 9.99 : 5.0;
      await Supabase.instance.client.from('subscriptions').insert({
        'user_id': Supabase.instance.client.auth.currentUser!.id,
        'plan_type': plan,
        'status': 'pending',
        'price_usd': price,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription request created. An administrator must activate it until live payments are connected.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request subscription: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  if (_subscriptions.isNotEmpty)
                    ..._subscriptions.map(
                      (subscription) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.workspace_premium_outlined),
                          title: Text('${subscription['plan_type']} plan'),
                          subtitle: Text(
                            '${subscription['status']} • ${Formatters.dateTime(subscription['created_at'])}',
                          ),
                          trailing: Text('US$ ${(subscription['price_usd'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    name: 'Individual',
                    price: r'$5 / month',
                    features: const ['Active directory listing', 'Customer calls and messages', 'Profile and reviews'],
                    onPressed: _requesting ? null : () => _request('individual'),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    name: 'Business / Group',
                    price: r'$9.99 / month',
                    features: const ['Business profile', 'Team-ready account foundation', 'Customer contacts and reviews'],
                    onPressed: _requesting ? null : () => _request('business'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Live mobile-money/card billing is intentionally not hard-coded into this starter repository. Connect your chosen payment gateway and activate subscriptions from a secure backend/webhook.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.name, required this.price, required this.features, required this.onPressed});
  final String name;
  final String price;
  final List<String> features;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(price, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 7),
                  Expanded(child: Text(feature)),
                ],
              ),
            )),
            const SizedBox(height: 10),
            FilledButton(onPressed: onPressed, child: const Text('Request activation')),
          ],
        ),
      ),
    );
  }
}
