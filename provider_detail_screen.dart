import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/launch_service.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/directory_repository.dart';
import '../../widgets/verified_badge.dart';
import '../chat/chat_screen.dart';

class ProviderDetailScreen extends StatefulWidget {
  const ProviderDetailScreen({super.key, required this.providerId});

  final String providerId;

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  late final DirectoryRepository _directory;
  Map<String, dynamic>? _provider;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _directory = DirectoryRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final provider = await _directory.providerDetails(widget.providerId);
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            customer_id,
            profiles!reviews_customer_id_fkey(display_name, avatar_url)
          ''')
          .eq('provider_id', widget.providerId)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _provider = provider;
          _reviews = List<Map<String, dynamic>>.from(reviews);
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _message() async {
    try {
      final conversationId = await ChatRepository(Supabase.instance.client)
          .getOrCreateConversation(widget.providerId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            title: _profile['display_name'] as String? ?? 'Provider',
            avatarUrl: _profile['avatar_url'] as String?,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $error')),
        );
      }
    }
  }

  Map<String, dynamic> get _profile {
    final value = _provider?['profiles'];
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  List<Map<String, dynamic>> get _services {
    final value = _provider?['services'];
    return value is List
        ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Professional profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _provider == null
              ? const Center(child: Text('Provider not found.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 48,
                          backgroundImage: _profile['avatar_url'] == null
                              ? null
                              : NetworkImage(_profile['avatar_url'] as String),
                          child: _profile['avatar_url'] == null
                              ? const Icon(Icons.person, size: 42)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _profile['display_name'] as String? ?? 'Provider',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      if (_provider!['is_verified'] == true)
                        const Center(child: VerifiedBadge()),
                      const SizedBox(height: 8),
                      Text(
                        _provider!['profession'] as String? ?? 'Service provider',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            ((_provider!['average_rating'] as num?)?.toDouble() ?? 0) == 0
                                ? 'New'
                                : ((_provider!['average_rating'] as num?)?.toDouble() ?? 0)
                                    .toStringAsFixed(1),
                          ),
                          const SizedBox(width: 8),
                          Text('(${_provider!['total_reviews'] ?? 0})'),
                        ],
                      ),
                      if (_provider!['location_label'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on_outlined, size: 18),
                            const SizedBox(width: 4),
                            Flexible(child: Text(_provider!['location_label'] as String)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _profile['phone'] == null
                                  ? null
                                  : () => LaunchService.callPhone(
                                        context,
                                        _profile['phone'] as String,
                                      ),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Call'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _message,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Message'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _InfoCard(
                        title: 'About',
                        child: Text(
                          (_profile['bio'] as String?)?.trim().isNotEmpty == true
                              ? _profile['bio'] as String
                              : 'This professional has not added an introduction yet.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Services',
                        child: _services.isEmpty
                            ? const Text('No services added yet.')
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _services.map((service) {
                                  return Chip(
                                    avatar: const Icon(Icons.check, size: 16),
                                    label: Text(service['service_name'] as String? ?? 'Service'),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Experience',
                        child: Text(
                          '${_provider!['years_experience'] ?? 0} years of experience',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Verification',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _CheckChip(
                              label: 'Phone',
                              enabled: _profile['phone'] != null,
                            ),
                            _CheckChip(
                              label: 'Identity',
                              enabled: _provider!['is_verified'] == true,
                            ),
                            _CheckChip(
                              label: 'Professional',
                              enabled: _provider!['is_verified'] == true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoCard(
                        title: 'Recent reviews',
                        child: _reviews.isEmpty
                            ? const Text('No reviews yet.')
                            : Column(
                                children: _reviews.map((review) {
                                  final reviewer = review['profiles'];
                                  final profile = reviewer is Map<String, dynamic>
                                      ? reviewer
                                      : <String, dynamic>{};
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundImage: profile['avatar_url'] == null
                                          ? null
                                          : NetworkImage(profile['avatar_url'] as String),
                                      child: profile['avatar_url'] == null
                                          ? const Icon(Icons.person_outline)
                                          : null,
                                    ),
                                    title: Text(profile['display_name'] as String? ?? 'Customer'),
                                    subtitle: Text(review['comment'] as String? ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, size: 16),
                                        Text('${review['rating']}'),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _CheckChip extends StatelessWidget {
  const _CheckChip({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(enabled ? Icons.check : Icons.remove, size: 16),
      label: Text(enabled ? '$label verified' : '$label pending'),
    );
  }
}
