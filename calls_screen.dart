import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/launch_service.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_profile.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/ring_repository.dart';
import '../ring/ring_status_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with WidgetsBindingObserver {
  late final RingRepository _rings;
  final _profileRepository = ProfileRepository(Supabase.instance.client);
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _incoming = [];
  AppProfile? _profile;
  Timer? _refreshTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rings = RingRepository(Supabase.instance.client);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final profile = await _profileRepository.getMyProfile();
      final history = await _rings.ringHistory();
      final incoming = profile?.role == AccountRole.provider
          ? await _rings.incomingRings()
          : <Map<String, dynamic>>[];
      if (mounted) {
        setState(() {
          _profile = profile;
          _history = history;
          _incoming = incoming;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load calls: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _accept(String ringId) async {
    try {
      await _rings.acceptRing(ringId);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RingStatusScreen(ringId: ringId)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This Ring was already answered or has expired: $error')),
        );
      }
    }
  }

  Future<void> _decline(String ringId) async {
    try {
      await _rings.declineRing(ringId);
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not decline Ring: $error')),
        );
      }
    }
  }

  String _titleForHistory(Map<String, dynamic> row) {
    final direction = row['direction'] as String?;
    final outgoing = direction == 'outgoing';
    final category = outgoing
        ? ((row['categories'] as Map?)?['name'] as String?)
        : (((row['ring_requests'] as Map?)?['categories'] as Map?)?['name'] as String?);
    return '${outgoing ? 'Outgoing' : 'Incoming'} ${category ?? 'Ring'}';
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = _profile?.role == AccountRole.provider;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls & Rings'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (isProvider && _incoming.isNotEmpty) ...[
                    Text(
                      'Incoming RINGs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ..._incoming.map(_incomingCard),
                    const SizedBox(height: 22),
                  ],
                  Text(
                    'History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (_history.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text('Your calls and Rings will appear here.'),
                      ),
                    )
                  else
                    ..._history.map(
                      (row) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              row['status'] == 'accepted'
                                  ? Icons.check
                                  : Icons.notifications_none,
                            ),
                          ),
                          title: Text(_titleForHistory(row)),
                          subtitle: Text(
                            '${row['status'] ?? 'unknown'} • ${Formatters.dateTime(row['created_at'])}',
                          ),
                          trailing: row['direction'] == 'outgoing'
                              ? const Icon(Icons.north_east)
                              : const Icon(Icons.south_west),
                          onTap: row['direction'] == 'outgoing'
                              ? () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => RingStatusScreen(
                                        ringId: row['id'] as String,
                                      ),
                                    ),
                                  )
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _incomingCard(Map<String, dynamic> row) {
    final ring = row['ring_requests'];
    final ringMap = ring is Map<String, dynamic> ? ring : <String, dynamic>{};
    final service = ringMap['service_name'] as String? ?? 'Service request';
    final expires = DateTime.tryParse(ringMap['expires_at']?.toString() ?? '');
    final secondsLeft = expires == null ? null : expires.difference(DateTime.now()).inSeconds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('INCOMING RING', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(service, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (secondsLeft != null && secondsLeft > 0)
                  Text('${secondsLeft}s'),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'A nearby customer is looking for this service. Accept to try to become the winner.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decline(row['ring_id'] as String),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _accept(row['ring_id'] as String),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
