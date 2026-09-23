import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, int> _counts = {};
  List<Map<String, dynamic>> _verification = [];
  List<Map<String, dynamic>> _subscriptions = [];
  bool _loading = true;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Future.wait([
        _client.from('profiles').select('id').count(CountOption.exact),
        _client.from('provider_profiles').select('user_id').count(CountOption.exact),
        _client.from('business_profiles').select('user_id').count(CountOption.exact),
        _client.from('subscriptions').select('id').count(CountOption.exact),
        _client.from('verification_requests').select('id').eq('status', 'pending').count(CountOption.exact),
        _client.from('verification_requests').select('''
          id,
          user_id,
          document_type,
          document_path,
          notes,
          status,
          submitted_at,
          profiles!verification_requests_user_id_fkey(display_name, email)
        ''').eq('status', 'pending').order('submitted_at', ascending: true).limit(50),
        _client.from('subscriptions').select('''
          id,
          user_id,
          plan_type,
          status,
          price_usd,
          created_at,
          profiles!subscriptions_user_id_fkey(display_name, email)
        ''').eq('status', 'pending').order('created_at', ascending: true).limit(50),
      ]);

      if (!mounted) return;
      setState(() {
        _counts = {
          'users': rows[0].count ?? 0,
          'providers': rows[1].count ?? 0,
          'businesses': rows[2].count ?? 0,
          'subscriptions': rows[3].count ?? 0,
          'pending_verification': rows[4].count ?? 0,
        };
        _verification = List<Map<String, dynamic>>.from(rows[5] as List);
        _subscriptions = List<Map<String, dynamic>>.from(rows[6] as List);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin data could not load: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reviewVerification(String id, String userId, bool approved) async {
    try {
      await _client.from('verification_requests').update({
        'status': approved ? 'approved' : 'rejected',
        'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        'reviewed_by': _client.auth.currentUser!.id,
      }).eq('id', id);

      if (approved) {
        await _client.from('provider_profiles').update({'is_verified': true}).eq('user_id', userId);
        await _client.from('business_profiles').update({'is_verified': true}).eq('user_id', userId);
        await _client.from('profiles').update({'is_verified': true}).eq('id', userId);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not review verification: $error')),
        );
      }
    }
  }

  Future<void> _viewDocument(String path) async {
    try {
      final url = await _client.storage
          .from('verification-documents')
          .createSignedUrl(path, 300);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Verification document',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('The document preview could not be displayed.'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $error')),
        );
      }
    }
  }

  Future<void> _activateSubscription(String id) async {
    try {
      final expires = DateTime.now().toUtc().add(const Duration(days: 30));
      await _client.from('subscriptions').update({
        'status': 'active',
        'starts_at': DateTime.now().toUtc().toIso8601String(),
        'expires_at': expires.toIso8601String(),
        'activated_by': _client.auth.currentUser!.id,
      }).eq('id', id);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not activate subscription: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _MetricCard(title: 'Users', value: '${_counts['users'] ?? 0}', icon: Icons.people_outline),
                      _MetricCard(title: 'Providers', value: '${_counts['providers'] ?? 0}', icon: Icons.work_outline),
                      _MetricCard(title: 'Businesses', value: '${_counts['businesses'] ?? 0}', icon: Icons.business_outlined),
                      _MetricCard(title: 'Subscriptions', value: '${_counts['subscriptions'] ?? 0}', icon: Icons.credit_card_outlined),
                      _MetricCard(title: 'Verification queue', value: '${_counts['pending_verification'] ?? 0}', icon: Icons.verified_user_outlined),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Verification queue', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_verification.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No pending verification requests.')))
                  else
                    ..._verification.map((row) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ((row['profiles'] as Map?)?['display_name'] as String?) ?? 'User',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text('Document: ${row['document_type'] ?? 'unknown'}')),
                                    TextButton.icon(
                                      onPressed: row['document_path'] == null
                                          ? null
                                          : () => _viewDocument(row['document_path'] as String),
                                      icon: const Icon(Icons.visibility_outlined),
                                      label: const Text('View'),
                                    ),
                                  ],
                                ),
                                if ((row['notes'] as String?)?.isNotEmpty == true) Text('Notes: ${row['notes']}'),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: OutlinedButton(onPressed: () => _reviewVerification(row['id'] as String, row['user_id'] as String, false), child: const Text('Reject'))),
                                    const SizedBox(width: 10),
                                    Expanded(child: FilledButton(onPressed: () => _reviewVerification(row['id'] as String, row['user_id'] as String, true), child: const Text('Approve'))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 22),
                  Text('Subscription requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (_subscriptions.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No pending subscriptions.')))
                  else
                    ..._subscriptions.map((row) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.workspace_premium_outlined),
                            title: Text('${((row['profiles'] as Map?)?['display_name'] as String?) ?? 'User'} — ${row['plan_type']}'),
                            subtitle: Text('US$ ${(row['price_usd'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                            trailing: FilledButton(onPressed: () => _activateSubscription(row['id'] as String), child: const Text('Activate')),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
