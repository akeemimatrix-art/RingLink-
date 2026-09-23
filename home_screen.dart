import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/launch_service.dart';
import '../../core/services/location_service.dart';
import '../../models/app_profile.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/directory_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../widgets/business_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/provider_card.dart';
import '../../widgets/section_header.dart';
import '../categories/category_screen.dart';
import '../profile/business_profile_screen.dart';
import '../locations/locations_screen.dart';
import '../providers/provider_detail_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DirectoryRepository _directory;
  late final BusinessRepository _businessRepository;
  final _profileRepository = ProfileRepository(Supabase.instance.client);
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _businesses = [];
  AppProfile? _profile;
  bool _loading = true;
  bool _usingFallbackLocation = false;

  @override
  void initState() {
    super.initState();
    _directory = DirectoryRepository(Supabase.instance.client);
    _businessRepository = BusinessRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final position = await LocationService.getCurrentPosition();
      final lat = position?.latitude ?? 0.3476;
      final lon = position?.longitude ?? 32.5825;
      _usingFallbackLocation = position == null;
      final results = await Future.wait([
        _directory.categories(),
        _profileRepository.getMyProfile(),
        _directory.searchProviders(
          latitude: lat,
          longitude: lon,
          radiusMeters: 3000,
          limit: 10,
        ),
        _businessRepository.nearbyBusinesses(
          latitude: lat,
          longitude: lon,
          radiusMeters: 5000,
          limit: 6,
        ),
      ]);
      _categories = List<Map<String, dynamic>>.from(results[0] as List);
      _profile = results[1] as AppProfile?;
      _providers = List<Map<String, dynamic>>.from(results[2] as List);
      _businesses = List<Map<String, dynamic>>.from(results[3] as List);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load Home: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 108,
            title: const Text('RingLink'),
            actions: [
              IconButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocationsScreen()),
                ),
                icon: const Icon(Icons.location_on_outlined),
                tooltip: 'Locations',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 10),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    _profile == null
                        ? 'Find trusted local services'
                        : 'Good to see you, ${_profile!.displayName.split(' ').first} 👋',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search),
                          SizedBox(width: 10),
                          Text('Search services, people, businesses...'),
                        ],
                      ),
                    ),
                  ),
                  if (_usingFallbackLocation) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Location permission is unavailable. Showing a Kampala starting point for development.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Popular categories',
                    actionLabel: 'See all',
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const SizedBox(
                      height: 96,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return _CategoryChip(
                            name: category['name'] as String? ?? 'Service',
                            iconName: category['icon_name'] as String?,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CategoryScreen(
                                  category: category,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: 'Nearby professionals',
                    actionLabel: 'Refresh',
                    onAction: _load,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_providers.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.search_off_outlined,
                  title: 'No listed professionals yet',
                  message:
                      'Add providers through the provider account flow, then they will appear here when their listing is active.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.builder(
                itemCount: _providers.length,
                itemBuilder: (context, index) {
                  final provider = _providers[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ProviderCard(
                      data: provider,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProviderDetailScreen(
                            providerId: provider['provider_id'] as String,
                          ),
                        ),
                      ),
                      onCall: (provider['phone'] as String?) == null
                          ? null
                          : () => LaunchService.callPhone(
                                context,
                                provider['phone'] as String,
                              ),
                    ),
                  );
                },
              ),
            ),
          if (!_loading && _businesses.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(
                      title: 'Nearby businesses',
                      actionLabel: 'Search',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen(initialType: 'businesses')),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._businesses.map(
                      (business) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BusinessCard(
                          data: business,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BusinessProfileScreen(
                                businessId: business['business_id'] as String,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.name, required this.iconName, required this.onTap});

  final String name;
  final String? iconName;
  final VoidCallback onTap;

  IconData _icon() {
    switch (iconName) {
      case 'plumbing':
        return Icons.plumbing;
      case 'bolt':
        return Icons.bolt;
      case 'motorcycle':
        return Icons.two_wheeler;
      case 'school':
        return Icons.school_outlined;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'computer':
        return Icons.computer_outlined;
      default:
        return Icons.handyman_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon(), size: 30),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
