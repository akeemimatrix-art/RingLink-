import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/media_repository.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _notesController = TextEditingController();
  String _documentType = 'national_id';
  String _status = 'none';
  String? _path;
  Uint8List? _bytes;
  String _extension = 'jpg';
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from('verification_requests')
          .select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (mounted && row != null) {
        setState(() {
          _status = row['status'] as String? ?? 'none';
          _path = row['document_path'] as String?;
          _documentType = row['document_type'] as String? ?? 'national_id';
          _notesController.text = row['notes'] as String? ?? '';
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load verification: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 1800);
    if (image == null) return;
    setState(() => _submitting = true);
    try {
      final bytes = await image.readAsBytes();
      final extension = image.name.split('.').last.toLowerCase();
      _bytes = bytes;
      _extension = extension.isEmpty ? 'jpg' : extension;
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (_bytes == null && _path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a document photo first.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      String? path = _path;
      if (_bytes != null) {
        path = await MediaRepository(Supabase.instance.client)
            .uploadVerificationDocument(_bytes!, _extension);
      }

      final existing = await Supabase.instance.client
          .from('verification_requests')
          .select('id,status')
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (existing != null && existing['status'] == 'rejected') {
        await Supabase.instance.client.from('verification_requests').update({
          'document_type': _documentType,
          'document_path': path,
          'notes': _notesController.text.trim(),
          'submitted_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'rejected',
        }).eq('id', existing['id'] as String);
      } else if (existing == null) {
        await Supabase.instance.client.from('verification_requests').insert({
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'document_type': _documentType,
          'document_path': path,
          'notes': _notesController.text.trim(),
        });
      } else {
        throw Exception('Your latest verification request is already ${existing['status']}.');
      }

      if (!mounted) return;
      setState(() {
        _status = existing?['status'] == 'rejected' ? 'rejected' : 'pending';
        _path = path;
        _bytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification request submitted for review.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${_status.toUpperCase()}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Verification documents are private. A RingLink administrator reviews them before the verified badge is applied.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _documentType,
            decoration: const InputDecoration(labelText: 'Document type'),
            items: const [
              DropdownMenuItem(value: 'national_id', child: Text('National ID')),
              DropdownMenuItem(value: 'driving_licence', child: Text('Driving licence')),
              DropdownMenuItem(value: 'teacher_id', child: Text('Teacher ID')),
              DropdownMenuItem(value: 'business_document', child: Text('Business document')),
            ],
            onChanged: (value) => setState(() => _documentType = value ?? 'national_id'),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _pickDocument,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(_bytes == null ? 'Choose document photo' : 'Document selected'),
          ),
          if (_bytes != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(_bytes!, height: 190, fit: BoxFit.cover),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes for reviewer',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Submit for verification'),
          ),
        ],
      ),
    );
  }
}
