import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/launch_service.dart';
import '../../core/services/location_service.dart';
import '../../repositories/directory_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/provider_card.dart';
import '../providers/provider_detail_screen.dart';
import '../search/search_screen.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.category});

  final Map<String, dynamic> category;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late final DirectoryRepository _directory;
  List<Map<String, dynamic>> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _directory = DirectoryRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _providers = await _directory.searchWithoutLocation(
          categoryId: widget.category['id'] as String,
        );
      } else {
        _providers = await _directory.searchProviders(
          latitude: position.latitude,
          longitude: position.longitude,
          categoryId: widget.category['id'] as String,
          radiusMeters: 10000,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load category: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.category['name'] as String? ?? 'Services';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SearchScreen(
                  initialCategoryId: widget.category['id'] as String,
                ),
              ),
            ),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.people_outline,
                    title: 'No providers listed yet',
                    message:
                        'This category is ready, but there are no active verified provider listings nearby.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _providers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final provider = _providers[index];
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
    );
  }
}
