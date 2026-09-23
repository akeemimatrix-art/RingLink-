import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_profile.dart';
import '../../repositories/profile_repository.dart';
import '../admin/admin_screen.dart';
import 'business_dashboard_screen.dart';
import 'business_setup_screen.dart';
import '../locations/locations_screen.dart';
import '../onboarding/profile_setup_screen.dart';
import '../settings/settings_screen.dart';
import '../subscriptions/subscription_screen.dart';
import '../verification/verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = ProfileRepository(Supabase.instance.client);
  AppProfile? _profile;
  Map<String, dynamic>? _provider;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repo.getMyProfile();
      Map<String, dynamic>? provider;
      if (profile?.role == AccountRole.provider) {
        provider = await _repo.getMyProvider();
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _provider = provider;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profile = _profile;
    if (profile == null) {
      return const Center(child: Text('Profile not found.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundImage: profile.avatarUrl == null
                        ? null
                        : NetworkImage(profile.avatarUrl!),
                    child: profile.avatarUrl == null
                        ? const Icon(Icons.person_outline, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(profile.role.label),
                        const SizedBox(height: 6),
                        if (profile.isVerified)
                          const Row(children: [Icon(Icons.verified, size: 18), SizedBox(width: 5), Text('Verified')]),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (profile.role == AccountRole.provider) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.business_center_outlined),
                    title: Text(
                      _provider?['profession'] as String? ?? 'Complete your provider profile',
                    ),
                    subtitle: Text(
                      _provider == null
                          ? 'Add profession, location and service category.'
                          : '${_provider!['years_experience'] ?? 0} years experience • ${(_provider!['is_available'] == true) ? 'Available' : 'Offline'}',
                    ),
                  ),
                  if (_provider == null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: FilledButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                          );
                          _load();
                        },
                        child: const Text('Complete provider profile'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _MenuCard(
            children: [
              if (profile.role == AccountRole.business)
                _MenuTile(
                  icon: Icons.business_outlined,
                  title: 'Business dashboard',
                  subtitle: 'Manage your local business listing',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BusinessDashboardScreen()),
                    );
                    _load();
                  },
                ),
              if (profile.role == AccountRole.business)
                _MenuTile(
                  icon: Icons.edit_business_outlined,
                  title: 'Edit business profile',
                  subtitle: 'Name, services and location',
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
                    );
                    _load();
                  },
                ),
              _MenuTile(
                icon: Icons.verified_user_outlined,
                title: 'Verification',
                subtitle: 'Identity and professional documents',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                ),
              ),
              _MenuTile(
                icon: Icons.location_on_outlined,
                title: 'Saved locations',
                subtitle: 'Home, work and favourites',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocationsScreen()),
                ),
              ),
              if (profile.role == AccountRole.provider || profile.role == AccountRole.business)
                _MenuTile(
                  icon: Icons.credit_card_outlined,
                  title: 'Subscription',
                  subtitle: 'Manage listing status and plan',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                  ),
                ),
              _MenuTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Account, security and privacy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              if (profile.role == AccountRole.admin)
                _MenuTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin dashboard',
                  subtitle: 'Moderation and platform controls',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(child: Column(children: children));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
