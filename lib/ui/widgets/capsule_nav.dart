import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'hoverable.dart';

class CapsuleNavItem {
  const CapsuleNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;
}

/// Playful replacement for [NavigationRail]: rounded candy capsules that pop
/// with a bounce when selected.
class CapsuleNav extends StatelessWidget {
  const CapsuleNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CapsuleNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.lg,
              bottom: AppSpacing.xl,
            ),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: AppTokens.candyGradient,
              ).createShader(bounds),
              child: const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          for (final (index, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CapsulePill(
                item: item,
                selected: index == selectedIndex,
                textSecondary: tokens.textSecondary,
                onTap: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _CapsulePill extends StatelessWidget {
  const _CapsulePill({
    required this.item,
    required this.selected,
    required this.textSecondary,
    required this.onTap,
  });

  final CapsuleNavItem item;
  final bool selected;
  final Color textSecondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 24,
      color: selected ? Colors.white : textSecondary,
    );

    // Re-keying on selection restarts the tween: the pill pops in with an
    // easeOutBack bounce every time it becomes active.
    return TweenAnimationBuilder<double>(
      key: ValueKey(selected),
      tween: Tween(begin: selected ? 0.8 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Hoverable(
        builder: (context, hovered) {
          return AnimatedContainer(
            duration: AppDurations.hover,
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppTokens.candyGradient,
                    )
                  : null,
              color: selected
                  ? null
                  : hovered
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.lg),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTokens.candyGradient.first.withValues(
                          alpha: 0.35,
                        ),
                        blurRadius: 14,
                      ),
                    ]
                  : const [],
            ),
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  if (item.badgeCount > 0)
                    Badge.count(count: item.badgeCount, child: icon)
                  else
                    icon,
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
