import 'package:flutter/material.dart';

import '../core/services/launch_service.dart';
import '../core/utils/formatters.dart';
import 'verified_badge.dart';

class BusinessCard extends StatelessWidget {
  const BusinessCard({super.key, required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = data['business_name'] as String? ?? 'Business';
    final phone = data['phone'] as String?;
    final verified = data['is_verified'] as bool? ?? false;
    final distance = (data['distance_meters'] as num?)?.toDouble();
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
                child: const Icon(Icons.business_outlined),
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
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
                    Text(data['location_label'] as String? ?? data['city'] as String? ?? 'Local business'),
                    if (distance != null) ...[
                      const SizedBox(height: 5),
                      Text(Formatters.distance(distance)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: phone == null ? null : () => LaunchService.callPhone(context, phone),
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
