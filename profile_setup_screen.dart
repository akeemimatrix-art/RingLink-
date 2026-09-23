import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/location_service.dart';
import '../../repositories/media_repository.dart';
import '../../repositories/profile_repository.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _profile = ProfileRepository(Supabase.instance.client);
  final _media = MediaRepository(Supabase.instance.client);
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController(text: 'Kampala');
  final _professionController = TextEditingController();
  final _experienceController = TextEditingController(text: '0');
  final _locationLabelController = TextEditingController(text: 'Kampala');
  final _servicesController = TextEditingController();
  String? _gender;
  String? _categoryId;
  bool _available = true;
  bool _loading = true;
  bool _isProvider = false;
  bool _saving = false;
  String? _avatarUrl;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _profile.getMyProfile();
      final provider = data?.role.dbValue == 'provider' ? await _profile.getMyProvider() : null;
      final categories = await _profile.listCategories();
      List<Map<String, dynamic>> providerServices = [];
      if (data?.role.dbValue == 'provider') {
        providerServices = await _profile.getProviderServices(data!.id);
      }
      if (mounted) {
        setState(() {
          _nameController.text = data?.displayName ?? '';
          _phoneController.text = data?.phone ?? '';
          _bioController.text = data?.bio ?? '';
          _cityController.text = data?.city ?? 'Kampala';
          _avatarUrl = data?.avatarUrl;
          _isProvider = data?.role.dbValue == 'provider';
          _gender = data?.gender;
          _categories = categories;
          if (provider != null) {
            if (providerServices.isNotEmpty) {
              _categoryId = providerServices.first['category_id'] as String?;
              final profession = provider['profession'] as String? ?? '';
              final extraServices = providerServices
                  .map((row) => row['service_name'] as String? ?? '')
                  .where((name) => name.trim().isNotEmpty && name.trim().toLowerCase() != profession.trim().toLowerCase())
                  .toSet()
                  .toList();
              _servicesController.text = extraServices.join(', ');
            }
            _professionController.text = provider['profession'] as String? ?? '';
            _experienceController.text = '${provider['years_experience'] ?? 0}';
            _locationLabelController.text = provider['location_label'] as String? ?? 'Kampala';
            _available = provider['is_available'] == true;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load setup: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (image == null) return;
    final Uint8List bytes = await image.readAsBytes();
    setState(() => _saving = true);
    try {
      final extension = image.name.split('.').last.toLowerCase();
      final url = await _media.uploadProfileImage(bytes, extension);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _profile.updateProfile(
        displayName: _nameController.text,
        phone: _phoneController.text,
        bio: _bioController.text,
        city: _cityController.text,
        gender: _gender,
        avatarUrl: _avatarUrl,
      );

      final me = await _profile.getMyProfile();
      if (me?.role.dbValue == 'provider') {
        if (_professionController.text.trim().isEmpty) {
          throw Exception('Provider accounts must enter a profession.');
        }
        if (_categoryId == null || _categoryId!.isEmpty) {
          throw Exception('Choose a primary category so customers can find you.');
        }
        final position = await LocationService.getCurrentPosition();
        if (position == null) {
          throw Exception('Allow location access so customers can find you nearby.');
        }
        final experience = int.tryParse(_experienceController.text.trim()) ?? 0;
        await _profile.upsertProviderProfile(
          profession: _professionController.text,
          yearsExperience: experience < 0 ? 0 : experience,
          isAvailable: _available,
          latitude: position.latitude,
          longitude: position.longitude,
          locationLabel: _locationLabelController.text,
          categoryId: _categoryId!,
          additionalServices: _servicesController.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _phoneController,
      _bioController,
      _cityController,
      _professionController,
      _experienceController,
      _locationLabelController,
      _servicesController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final isProvider = _isProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                  child: _avatarUrl == null ? const Icon(Icons.person_outline, size: 42) : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    onPressed: _saving ? null : _pickImage,
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other / prefer not to say')),
            ],
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: 'City / area'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'About you',
              alignLabelWithHint: true,
              hintText: 'Introduce yourself or your business.',
            ),
          ),
          if (isProvider) ...[
            const SizedBox(height: 22),
            Text(
              'Provider information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _professionController,
              decoration: const InputDecoration(
                labelText: 'Main profession',
                hintText: 'Example: Plumber',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categories.any((c) => c['id'] == _categoryId) ? _categoryId : null,
              decoration: const InputDecoration(labelText: 'Primary category'),
              items: _categories
                  .map((category) => DropdownMenuItem<String>(
                        value: category['id'] as String,
                        child: Text(category['name'] as String? ?? 'Category'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servicesController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Additional services',
                hintText: 'Separate services with commas',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _experienceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Years of experience'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationLabelController,
              decoration: const InputDecoration(labelText: 'Location label'),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Available for customers'),
              value: _available,
              onChanged: (value) => setState(() => _available = value),
            ),
            const Text(
              'Your device location is used when you save the provider profile so nearby customers can discover you. You can update it whenever you edit the profile.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save profile'),
          ),
        ],
      ),
    );
  }
}
