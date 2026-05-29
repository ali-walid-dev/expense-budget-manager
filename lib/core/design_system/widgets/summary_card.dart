import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.progress,
    this.delta,
    this.deltaSuffix,
    this.onTap,
  });

  final String title;
  final String value;
  final double? progress;
  final int? delta;
  final String? deltaSuffix;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 6),
              Text(value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const Spacer(),
              if (progress != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: progress! >= 1.0 ? scheme.error : scheme.primary,
                  ),
                )
              else if (delta != null)
                Text(
                  '${delta! >= 0 ? '↑' : '↓'} ${delta!.abs()}% ${deltaSuffix ?? ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: delta! >= 0 ? scheme.error : scheme.primary,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
