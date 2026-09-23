import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import 'verified_badge.dart';

class ProviderCard extends StatelessWidget {
  const ProviderCard({
    super.key,
    required this.data,
    required this.onTap,
    this.onCall,
  });

  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final name = data['display_name'] as String? ?? 'Provider';
    final profession = data['profession'] as String? ?? 'Service provider';
    final avatar = data['avatar_url'] as String?;
    final rating = (data['average_rating'] as num?)?.toDouble() ?? 0;
    final distance = (data['distance_meters'] as num?)?.toDouble();
    final verified = data['is_verified'] as bool? ?? false;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: avatar == null ? null : NetworkImage(avatar),
                child: avatar == null ? const Icon(Icons.person_outline) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (verified) ...[
                          const SizedBox(width: 8),
                          const VerifiedBadge(compact: true),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(profession),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 16),
                        const SizedBox(width: 4),
                        Text(rating == 0 ? 'New' : rating.toStringAsFixed(1)),
                        if (distance != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 3),
                          Text(Formatters.distance(distance)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Call',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
