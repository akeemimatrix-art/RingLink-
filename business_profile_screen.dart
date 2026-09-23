import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/launch_service.dart';
import '../../widgets/verified_badge.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key, required this.businessId});
  final String businessId;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Map<String, dynamic>? _business;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final business = await client.from('business_profiles').select().eq('user_id', widget.businessId).maybeSingle();
      final services = await client.from('business_services').select('service_name,categories(name)').eq('business_id', widget.businessId).order('service_name');
      if (mounted) setState(() => _business = business == null ? null : {...business, 'services': List<Map<String, dynamic>>.from(services)});
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load business: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final business = _business;
    if (business == null) return const Scaffold(body: Center(child: Text('Business not found.')));
    final services = (business['services'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final phone = business['phone'] as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          const CircleAvatar(radius: 46, child: Icon(Icons.business_outlined, size: 44)),
          const SizedBox(height: 14),
          Text(business['business_name'] as String? ?? 'Business', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          if (business['is_verified'] == true) const Center(child: VerifiedBadge()),
          const SizedBox(height: 8),
          Text(business['location_label'] as String? ?? business['city'] as String? ?? 'Local business', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: phone == null ? null : () => LaunchService.callPhone(context, phone), icon: const Icon(Icons.call), label: const Text('Call business')),
          const SizedBox(height: 18),
          _Info(title: 'About', child: Text(business['description'] as String? ?? 'No description yet.')),
          const SizedBox(height: 12),
          _Info(
            title: 'Services',
            child: services.isEmpty
                ? const Text('No services listed yet.')
                : Wrap(spacing: 8, runSpacing: 8, children: services.map((service) => Chip(label: Text(service['service_name'] as String? ?? 'Service'))).toList()),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 10), child])));
  }
}
