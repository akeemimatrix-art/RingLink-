import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/location_service.dart';
import '../../repositories/business_repository.dart';
import '../../repositories/profile_repository.dart';

class BusinessSetupScreen extends StatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends State<BusinessSetupScreen> {
  final _business = BusinessRepository(Supabase.instance.client);
  final _profile = ProfileRepository(Supabase.instance.client);
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController(text: 'Kampala');
  final _location = TextEditingController(text: 'Kampala');
  final _services = TextEditingController();
  String? _categoryId;
  bool _available = true;
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _business.myBusiness();
      final categories = await _profile.listCategories();
      final services = data == null ? <Map<String, dynamic>>[] : await _business.services(data['user_id'] as String);
      if (mounted) {
        setState(() {
          _categories = categories;
          _name.text = data?['business_name'] as String? ?? '';
          _description.text = data?['description'] as String? ?? '';
          _phone.text = data?['phone'] as String? ?? '';
          _city.text = data?['city'] as String? ?? 'Kampala';
          _location.text = data?['location_label'] as String? ?? 'Kampala';
          _available = data?['is_available'] != false;
          _categoryId = services.isEmpty ? null : services.first['category_id'] as String?;
          _services.text = services
              .map((row) => row['service_name'] as String? ?? '')
              .where((name) => name.trim().isNotEmpty && name.trim().toLowerCase() != (_name.text.trim().toLowerCase()))
              .toSet()
              .join(', ');
        });
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load business setup: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your business name.')));
      return;
    }
    if (_categoryId == null || _categoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a main category.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position == null) throw Exception('Allow location access so customers can find your business.');
      await _business.upsertBusiness(
        businessName: _name.text,
        description: _description.text,
        phone: _phone.text,
        city: _city.text,
        locationLabel: _location.text,
        latitude: position.latitude,
        longitude: position.longitude,
        isAvailable: _available,
        categoryId: _categoryId!,
        additionalServices: _services.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business profile saved.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save business: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _city.dispose();
    _location.dispose();
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Business profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Business name')),
          const SizedBox(height: 12),
          TextField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Business phone')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categories.any((c) => c['id'] == _categoryId) ? _categoryId : null,
            decoration: const InputDecoration(labelText: 'Main category'),
            items: _categories.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _services,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Services',
              hintText: 'Separate services with commas',
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City / area')),
          const SizedBox(height: 12),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location label')),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open / available'),
            value: _available,
            onChanged: (value) => setState(() => _available = value),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Save business')),
        ],
      ),
    );
  }
}
