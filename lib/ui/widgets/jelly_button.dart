import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'block_asset.dart';
import 'hoverable.dart';

/// 主操作色调：candy 为冒险蓝渐变（默认）；sunny 为积木黄渐变，
/// 用于规范 §4.3/§13.2 规定的播放、奖励、抽卡等页面最强操作。
enum JellyTone { candy, sunny }

/// Chunky primary brick button with a springy focus/hover response.
class JellyButton extends StatelessWidget {
  const JellyButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = JellyTone.candy,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final JellyTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final sunny = tone == JellyTone.sunny;
    final gradient = sunny ? AppTokens.sunnyGradient : AppTokens.candyGradient;
    // 积木黄底配深色文字（规范：白色或深色高对比文字）。
    final foreground = sunny ? AppTokens.onLightBrick : tokens.brickHighlight;
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
              gradient: LinearGradient(colors: gradient),
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(
                color: sunny
                    ? tokens.brickHighlight.withValues(alpha: 0.72)
                    : tokens.brickHighlight.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.hardShadow,
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
                      BlockIcon.fromMaterial(
                        icon,
                        size: 28,
                        color: foreground,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        label,
                        style: TextStyle(
                          color: foreground,
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
