import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/location_service.dart';
import '../../repositories/location_repository.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _repo = LocationRepository(Supabase.instance.client);
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await _repo.listSavedLocations();
      if (mounted) setState(() => _locations = rows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load locations: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    bool favorite = false;
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Save location'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: labelController, decoration: const InputDecoration(labelText: 'Label', hintText: 'Home')),
                const SizedBox(height: 10),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address / area', hintText: 'Kampala')),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: favorite,
                  onChanged: (value) => setDialogState(() => favorite = value ?? false),
                  title: const Text('Favourite'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          ),
        ),
      );
      if (result != true) return;
      if (labelController.text.trim().isEmpty || addressController.text.trim().isEmpty) {
        throw Exception('Enter a label and address.');
      }
      final position = await LocationService.getCurrentPosition();
      if (position == null) throw Exception('Allow location access to save your current location.');
      await _repo.addLocation(
        label: labelController.text,
        addressLabel: addressController.text,
        latitude: position.latitude,
        longitude: position.longitude,
        isFavorite: favorite,
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      labelController.dispose();
      addressController.dispose();
    }
  }

  Future<void> _delete(String id) async {
    await _repo.deleteLocation(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved locations'),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _locations.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(child: Text('No saved locations yet.')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _locations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = _locations[index];
                        return Card(
                          child: ListTile(
                            leading: Icon(row['is_favorite'] == true ? Icons.star : Icons.location_on_outlined),
                            title: Text(row['label'] as String? ?? 'Location'),
                            subtitle: Text(row['address_label'] as String? ?? ''),
                            trailing: IconButton(
                              onPressed: () => _delete(row['id'] as String),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
