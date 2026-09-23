import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/services/location_service.dart';
import '../../repositories/directory_repository.dart';
import '../../repositories/ring_repository.dart';
import 'ring_status_screen.dart';

class RingScreen extends StatefulWidget {
  const RingScreen({super.key});

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  late final DirectoryRepository _directory;
  late final RingRepository _rings;
  List<Map<String, dynamic>> _categories = [];
  String? _categoryId;
  final _serviceController = TextEditingController();
  double _radius = AppConfig.defaultRadiusMeters;
  bool _loading = true;
  bool _ringing = false;

  @override
  void initState() {
    super.initState();
    _directory = DirectoryRepository(Supabase.instance.client);
    _rings = RingRepository(Supabase.instance.client);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _directory.categories();
      if (mounted) {
        setState(() {
          _categories = rows;
          if (_categories.isNotEmpty) _categoryId ??= _categories.first['id'] as String;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load categories: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ring() async {
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a category first.')),
      );
      return;
    }
    if (_serviceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe what you need.')),
      );
      return;
    }

    setState(() => _ringing = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Location permission is required to use RING.');
      }

      final ringId = await _rings.createRing(
        categoryId: _categoryId!,
        serviceName: _serviceController.text,
        latitude: position.latitude,
        longitude: position.longitude,
        radiusMeters: _radius,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RingStatusScreen(ringId: ringId)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start RING: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _ringing = false);
    }
  }

  @override
  void dispose() {
    _serviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _categories.cast<Map<String, dynamic>?>().firstWhere(
          (category) => category?['id'] == _categoryId,
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Ring a nearby provider')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              children: [
                Text(
                  'What do you need?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a category and describe the job. RingLink will create a request for eligible nearby providers.',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem<String>(
                          value: category['id'] as String,
                          child: Text(category['name'] as String? ?? 'Category'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _serviceController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Describe what you need',
                    hintText: 'Example: Fix a leaking kitchen pipe',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Search radius: ${(_radius / 1000).toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: _radius,
                  min: 500,
                  max: 5000,
                  divisions: 9,
                  label: '${(_radius / 1000).toStringAsFixed(1)} km',
                  onChanged: (value) => setState(() => _radius = value),
                ),
                if (selectedCategory != null) ...[
                  const SizedBox(height: 8),
                  Text('Category: ${selectedCategory['name']}'),
                ],
                const SizedBox(height: 30),
                Center(
                  child: GestureDetector(
                    onTap: _ringing ? null : _ring,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: _ringing ? 28 : 18,
                            spreadRadius: _ringing ? 10 : 4,
                            color: Theme.of(context).colorScheme.primary.withAlpha(50),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            color: Colors.white,
                            size: 52,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ringing ? 'STARTING' : 'RING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'V1 note: RING creates the real-time provider request in Supabase. Full simultaneous carrier/VoIP calling is a separate telephony integration step.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
    );
  }
}
