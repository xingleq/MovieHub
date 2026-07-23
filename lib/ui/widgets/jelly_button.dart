import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'block_asset.dart';
import 'hoverable.dart';

/// Chunky primary brick button with a springy focus/hover response.
class JellyButton extends StatelessWidget {
  const JellyButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onActivate: onPressed,
      builder: (context, hovered) {
        return AnimatedScale(
          scale: hovered ? 1.04 : 1.0,
          duration: AppDurations.hover,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: AppDurations.hover,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTokens.candyGradient),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(
                color: AppTokens.of(
                  context,
                ).brickHighlight.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTokens.of(context).hardShadow,
                  blurRadius: 0,
                  offset: Offset(hovered ? 7 : 5, hovered ? 7 : 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
                ),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md + 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlockIcon.fromMaterial(icon, size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppTokens.of(context).brickHighlight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
