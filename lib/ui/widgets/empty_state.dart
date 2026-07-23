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
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final String? illustrationAsset;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: tokens.surface.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
            border: Border.all(color: tokens.cardBorder, width: 3),
            boxShadow: [
              BoxShadow(
                color: tokens.accent.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustrationAsset case final asset?)
                BlockIllustration(asset: asset, size: 150, semanticLabel: title)
              else
                Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.brickYellow,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                    border: Border.all(color: tokens.cardBorder, width: 2),
                  ),
                  child: BlockIcon.fromMaterial(icon, size: 46),
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
