import 'package:flutter/material.dart';

import '../services/outbox_queue.dart';

class OutboxBadge extends StatelessWidget {
  const OutboxBadge({
    super.key,
    required this.outbox,
    this.onTap,
  });

  final OutboxQueue outbox;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: outbox.countPending(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ActionChip(
            label: Text('$count'),
            avatar: const Icon(Icons.cloud_upload_outlined, size: 18),
            onPressed: onTap,
          ),
        );
      },
    );
  }
}
