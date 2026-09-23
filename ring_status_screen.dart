import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/launch_service.dart';
import '../../repositories/ring_repository.dart';
import '../reviews/review_screen.dart';

class RingStatusScreen extends StatefulWidget {
  const RingStatusScreen({super.key, required this.ringId});

  final String ringId;

  @override
  State<RingStatusScreen> createState() => _RingStatusScreenState();
}

class _RingStatusScreenState extends State<RingStatusScreen> {
  late final RingRepository _rings;
  Map<String, dynamic>? _ring;
  List<Map<String, dynamic>> _participants = [];
  StreamSubscription<List<Map<String, dynamic>>>? _participantSubscription;
  StreamSubscription<Map<String, dynamic>?>? _ringSubscription;
  Timer? _timer;
  DateTime? _expiresAt;
  int _secondsLeft = 0;
  bool _loading = true;
  bool _expirySubmitted = false;
  bool _isCustomer = false;
  Map<String, dynamic>? _contact;

  @override
  void initState() {
    super.initState();
    _rings = RingRepository(Supabase.instance.client);
    _start();
  }

  Future<void> _start() async {
    try {
      _ring = await _rings.getRing(widget.ringId);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      _isCustomer = currentUserId != null && _ring?['customer_id'] == currentUserId;
      _participantSubscription = _rings
          .watchRingParticipants(widget.ringId)
          .listen((rows) {
        if (mounted) setState(() => _participants = rows);
      });
      _ringSubscription = _rings.watchRing(widget.ringId).listen((ring) {
        if (!mounted || ring == null) return;
        setState(() => _ring = ring);
        if ((ring['status'] as String?) == 'accepted' && _contact == null) {
          _loadContact();
        }
        final expires = DateTime.tryParse(ring['expires_at']?.toString() ?? '');
        if (expires != null) _setExpiry(expires);
      });
      final expires = DateTime.tryParse(_ring?['expires_at']?.toString() ?? '');
      if (expires != null) _setExpiry(expires);
      if ((_ring?['status'] as String?) == 'accepted') {
        await _loadContact();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load Ring: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadContact() async {
    try {
      final row = await _rings.getRingContact(widget.ringId);
      if (mounted) setState(() => _contact = row);
    } catch (_) {}
  }

  void _setExpiry(DateTime expires) {
    _expiresAt = expires.toLocal();
    _timer?.cancel();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_expiresAt == null || !mounted) return;
    final remaining = _expiresAt!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _timer?.cancel();
      if (!_expirySubmitted && (_ring?['status'] as String? ?? 'ringing') == 'ringing') {
        _expirySubmitted = true;
        _rings.expireRing(widget.ringId).catchError((_) {});
      }
      setState(() => _secondsLeft = 0);
    } else {
      setState(() => _secondsLeft = remaining);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _participantSubscription?.cancel();
    _ringSubscription?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    await _rings.cancelRing(widget.ringId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = _ring?['status'] as String? ?? 'ringing';
    final winnerId = _ring?['winner_provider_id'] as String?;
    final isActive = status == 'ringing' && _secondsLeft > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('RING status')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Icon(
                status == 'accepted' ? Icons.check_circle_outline : Icons.notifications_active_outlined,
                color: Colors.white,
                size: 70,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            status == 'accepted'
                ? 'Provider accepted'
                : status == 'expired'
                    ? 'No one accepted'
                    : status == 'cancelled'
                        ? 'RING cancelled'
                        : 'RINGING...',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _ring?['service_name'] as String? ?? 'Service request',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (isActive) ...[
            Text(
              '$_secondsLeft seconds left',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Providers reached'),
                      Text('${_participants.length}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Radius'),
                      Text('${((_ring?['radius_meters'] as num?)?.toDouble() ?? 0) / 1000} km'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (winnerId != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(_contact?['role'] == 'customer' ? Icons.person_outline : Icons.verified_outlined),
                ),
                title: Text(
                  _contact?['display_name'] as String? ?? 'Connection made',
                ),
                subtitle: Text(
                  _contact?['role'] == 'customer'
                      ? 'Customer'
                      : 'Verified service provider',
                ),
              ),
            ),
            const SizedBox(height: 8),
            if ((_contact?['phone'] as String?)?.isNotEmpty == true)
              FilledButton.icon(
                onPressed: () => LaunchService.callPhone(
                  context,
                  _contact!['phone'] as String,
                ),
                icon: const Icon(Icons.call),
                label: Text(_contact?['role'] == 'customer' ? 'Call customer' : 'Call provider'),
              ),
            if (_isCustomer && _contact?['role'] == 'provider')
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewScreen(
                      providerId: winnerId,
                      ringId: widget.ringId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.star_outline),
                label: const Text('Leave a review'),
              ),
          ],
          const SizedBox(height: 22),
          if (isActive)
            OutlinedButton(
              onPressed: _cancel,
              child: const Text('Cancel Ring'),
            )
          else
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
        ],
      ),
    );
  }
}
