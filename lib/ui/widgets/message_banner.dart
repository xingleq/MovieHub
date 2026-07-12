import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Inline warning/error banner.
class MessageBanner extends StatelessWidget {
  const MessageBanner({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

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
          ],
        ),
      ),
    );
  }
}
