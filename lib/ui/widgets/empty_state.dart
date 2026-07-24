import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'block_asset.dart';

/// Centered icon + title + message for empty lists and missing selections.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.illustrationAsset,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final String? illustrationAsset;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustrationAsset case final asset?)
                BlockIcon(
                  asset,
                  size: 96,
                  color: accentColor ?? tokens.accent,
                  semanticLabel: title,
                )
              else
                BlockIcon.fromMaterial(
                  icon,
                  size: 72,
                  color: accentColor ?? tokens.brickYellow,
                ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: TextStyle(color: tokens.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
