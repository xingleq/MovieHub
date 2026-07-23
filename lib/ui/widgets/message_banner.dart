import 'package:flutter/material.dart';

import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import 'block_asset.dart';

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
    final tokens = AppTokens.of(context);
    return Card(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        side: BorderSide(color: tokens.brickYellow, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.brickYellow,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.sm),
                ),
              ),
              child: BlockIcon.fromMaterial(icon, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(message)),
            if (onClose != null) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                tooltip: '关闭',
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: const BlockIcon(AppAssets.close, size: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
