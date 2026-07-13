import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'hoverable.dart';

/// Candy-gradient pill button with a springy hover bounce — the primary
/// play action in the anime-styled UI.
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
      builder: (context, hovered) {
        return AnimatedScale(
          scale: hovered ? 1.06 : 1.0,
          duration: AppDurations.hover,
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: AppDurations.hover,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTokens.candyGradient),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.pill),
              ),
              boxShadow: hovered
                  ? [
                      BoxShadow(
                        color: AppTokens.candyGradient.first.withValues(
                          alpha: 0.5,
                        ),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.pill),
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
                      Icon(icon, color: Colors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
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
