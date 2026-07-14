import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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

/// Wide side navigation with a compact brand mark, icon+label entries, and an
/// optional footer.
class CapsuleNav extends StatelessWidget {
  const CapsuleNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.footer,
  });

  final List<CapsuleNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);

    return SizedBox(
      width: 176,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(tokens: tokens),
            const SizedBox(height: AppSpacing.xl),
            for (final (index, item) in items.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _NavEntry(
                  item: item,
                  selected: index == selectedIndex,
                  textSecondary: tokens.textSecondary,
                  onTap: () => onSelected(index),
                ),
              ),
            const Spacer(),
            const _Mascot(),
            const SizedBox(height: AppSpacing.md),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Side-rail visual anchor. The animation intentionally stays independent of
/// navigation state, so replacing the mascot asset never affects app flow.
class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 154,
        child: Lottie.asset(
          'assets/animations/mascot.json',
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.tokens});

  final AppTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.accent.withValues(alpha: 0.22),
                  blurRadius: 12,
                ),
              ],
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
                ),
                child: Image.asset(
                  'assets/images/branding/moviehub-mascot.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTokens.candyGradient,
                          ),
                        ),
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: AppTokens.candyGradient,
              ).createShader(bounds),
              child: const Text(
                'MovieHub',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavEntry extends StatelessWidget {
  const _NavEntry({
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
      size: 20,
      color: selected ? Colors.white : textSecondary,
    );

    return TweenAnimationBuilder<double>(
      key: ValueKey(selected),
      tween: Tween(begin: selected ? 0.9 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Hoverable(
        builder: (context, hovered) {
          return GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: AppDurations.hover,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: AppTokens.candyGradient,
                      )
                    : null,
                color: selected
                    ? null
                    : hovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
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
              child: Row(
                children: [
                  if (item.badgeCount > 0)
                    Badge.count(count: item.badgeCount, child: icon)
                  else
                    icon,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? Colors.white : textSecondary,
                      ),
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
