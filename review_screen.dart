import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/review_repository.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.providerId, this.ringId});

  final String providerId;
  final String? ringId;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await ReviewRepository(Supabase.instance.client).addReview(
        providerId: widget.providerId,
        rating: _rating,
        comment: _commentController.text,
        ringId: widget.ringId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted.')));
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit review: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave a review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('How was your experience?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final selected = index < _rating;
              return IconButton(
                onPressed: () => setState(() => _rating = index + 1),
                icon: Icon(selected ? Icons.star : Icons.star_border),
                iconSize: 40,
              );
            }),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _commentController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Comment', alignLabelWithHint: true),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _saving ? null : _submit, child: const Text('Submit review')),
        ],
      ),
    );
  }
}
