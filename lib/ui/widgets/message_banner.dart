import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Inline warning/error banner. Pass [onClose] to let the user dismiss it.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.icon,
    required this.message,
    this.onClose,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF241E12),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFFC857)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
            if (onClose != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
