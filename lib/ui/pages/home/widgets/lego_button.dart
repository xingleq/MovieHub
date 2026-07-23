import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../theme/app_tokens.dart';
import 'focus_scale.dart';

class LegoButton extends StatelessWidget {
  const LegoButton({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.onPressed,
    this.subtitle,
    this.primary = true,
    this.autofocus = false,
  });

  final String label;
  final String iconAsset;
  final VoidCallback onPressed;
  final String? subtitle;
  final bool primary;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return FocusScale(
      onActivate: onPressed,
      autofocus: autofocus,
      focusScale: 1.05,
      hoverScale: 1.02,
      builder: (context, status) {
        final faceColor = primary ? tokens.accent : tokens.surface;
        final foreground = primary ? tokens.brickHighlight : tokens.accent;
        final lift = status.pressed
            ? 5.0
            : status.highlighted
            ? 0.0
            : 3.0;
        return SizedBox(
          height: subtitle == null ? 58 : 76,
          child: Stack(
            children: [
              Positioned.fill(
                top: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: primary ? tokens.hardShadow : tokens.cardBorder,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: AppDurations.hover,
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                top: lift,
                bottom: 7 - lift,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: faceColor,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.md),
                    ),
                    border: Border.all(
                      color: status.focused
                          ? tokens.brickHighlight
                          : primary
                          ? tokens.accent
                          : tokens.cardBorder,
                      width: status.focused ? 3 : 2,
                    ),
                    boxShadow: status.highlighted
                        ? [
                            BoxShadow(
                              color: tokens.accent.withValues(alpha: 0.42),
                              blurRadius: 22,
                            ),
                          ]
                        : const [],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          iconAsset,
                          width: 30,
                          height: 30,
                          colorFilter: ColorFilter.mode(
                            foreground,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Flexible(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (subtitle case final String value)
                                Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground.withValues(alpha: 0.82),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
