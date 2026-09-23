import 'package:flutter/material.dart';

import '../../core/services/launch_service.dart';
import '../../repositories/business_repository.dart';
import '../../core/services/location_service.dart';
import '../../core/config/app_config.dart';
import '../../repositories/directory_repository.dart';
import '../../widgets/business_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/provider_card.dart';
import '../providers/provider_detail_screen.dart';
import '../profile/business_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialCategoryId, this.initialType = 'providers'});

  final String? initialCategoryId;
  final String initialType;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final DirectoryRepository _directory;
  late final BusinessRepository _business;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  late String _type;
  double _radius = AppConfig.defaultRadiusMeters;
  bool _loading = false;
  bool _locationUnavailable = false;

  @override
  void initState() {
    super.initState();
    _directory = DirectoryRepository(Supabase.instance.client);
    _business = BusinessRepository(Supabase.instance.client);
    _categoryId = widget.initialCategoryId;
    _type = widget.initialType == 'businesses' ? 'businesses' : 'providers';
    _loadCategories();
    _search();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _directory.categories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final position = await LocationService.getCurrentPosition();
      final lat = position?.latitude ?? 0.3476;
      final lon = position?.longitude ?? 32.5825;
      _locationUnavailable = position == null;
      if (_type == 'businesses') {
        _results = await _business.nearbyBusinesses(
          latitude: lat,
          longitude: lon,
          radiusMeters: position == null ? 50000 : _radius,
          categoryId: _categoryId,
          query: _searchController.text,
        );
      } else if (position == null) {
        _results = await _directory.searchWithoutLocation(
          query: _searchController.text,
          categoryId: _categoryId,
        );
      } else {
        _results = await _directory.searchProviders(
          latitude: position.latitude,
          longitude: position.longitude,
          radiusMeters: _radius,
          categoryId: _categoryId,
          query: _searchController.text,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search services')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Plumber, tutor, mechanic...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterButton(
                  icon: Icons.people_outline,
                  label: _type == 'businesses' ? 'Businesses' : 'People',
                  onTap: _chooseType,
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  icon: Icons.category_outlined,
                  label: _categoryId == null
                      ? 'Category'
                      : (_categories.firstWhere(
                              (c) => c['id'] == _categoryId,
                              orElse: () => {'name': 'Category'},
                            )['name'] as String),
                  onTap: _chooseCategory,
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  icon: Icons.location_on_outlined,
                  label: '${(_radius / 1000).toStringAsFixed(1)} km',
                  onTap: _chooseRadius,
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  icon: Icons.refresh,
                  label: 'Refresh',
                  onTap: _search,
                ),
              ],
            ),
          ),
          if (_locationUnavailable)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Location is unavailable, so results are not distance-filtered.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: EmptyState(
                          icon: Icons.search_off_outlined,
                          title: _type == 'businesses' ? 'No businesses found' : 'No providers found',
                          message:
                              'Try a wider radius, another category, or a different search term.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _search,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final provider = _results[index];
                            if (_type == 'businesses') {
                              return BusinessCard(
                                data: provider,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BusinessProfileScreen(
                                      businessId: provider['business_id'] as String,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return ProviderCard(
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
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseType() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.people_outline), title: const Text('People / service providers'), onTap: () => Navigator.pop(context, 'providers')),
          ListTile(leading: const Icon(Icons.business_outlined), title: const Text('Businesses'), onTap: () => Navigator.pop(context, 'businesses')),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (!mounted || value == null) return;
    setState(() => _type = value);
    await _search();
  }

  Future<void> _chooseCategory() async {
    final value = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('All categories'),
            onTap: () => Navigator.pop(context, 'ALL'),
          ),
          ..._categories.map(
            (category) => ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(category['name'] as String? ?? 'Category'),
              onTap: () => Navigator.pop(context, category['id'] as String),
            ),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    setState(() => _categoryId = value == 'ALL' ? null : value);
    await _search();
  }

  Future<void> _chooseRadius() async {
    final value = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Search radius',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Slider(
                  value: _radius,
                  min: 500,
                  max: 10000,
                  divisions: 19,
                  label: '${(_radius / 1000).toStringAsFixed(1)} km',
                  onChanged: (value) {
                    setModalState(() {});
                    _radius = value;
                  },
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _radius),
                  child: const Text('Use radius'),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (!mounted || value == null) return;
    setState(() => _radius = value);
    await _search();
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
