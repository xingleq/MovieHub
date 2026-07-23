import 'package:flutter/material.dart';

import '../../app/settings_controller.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import 'block_asset.dart';

/// Full-window forced-break lock, shown above every route (mounted in
/// MaterialApp.builder). Carries its own [Material]: at that position in the
/// tree there is no Material ancestor, and without one Text falls back to
/// the yellow-underlined error style.
class ScreenTimeOverlay extends StatelessWidget {
  const ScreenTimeOverlay({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.showBreakOverlay) {
      return const SizedBox.shrink();
    }

    final dailyLimitReached = settings.dailyViewingLimitReached;
    final remaining = settings.breakRemaining;
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final tokens = AppTokens.of(context);

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.scrim,
            backgroundBlendMode: BlendMode.srcOver,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: -26,
                      right: 26,
                      child: Icon(
                        Icons.nightlight_round,
                        color: tokens.brickYellow,
                        size: 44,
                      ),
                    ),
                    Positioned(
                      top: -6,
                      left: 10,
                      child: Icon(
                        Icons.auto_awesome,
                        color: tokens.brickPurple,
                        size: 28,
                      ),
                    ),
                    _BreakCard(
                      dailyLimitReached: dailyLimitReached,
                      dailyLimit: settings.todayDailyWatchLimit,
                      hours: hours,
                      minutes: minutes,
                      seconds: seconds,
                      onClose: settings.dismissBreakOverlay,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  dailyLimitReached
                      ? '今天先好好休息，明天再继续探索吧！✨'
                      : '自律一点，才能更好地遇见喜欢的世界哦！✨',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BreakCard extends StatelessWidget {
  const _BreakCard({
    required this.dailyLimitReached,
    required this.dailyLimit,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.onClose,
  });

  final bool dailyLimitReached;
  final int dailyLimit;
  final String hours;
  final String minutes;
  final String seconds;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: 520,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.surfaceVariant, tokens.surface],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        border: Border.all(color: tokens.brickYellow, width: 4),
        boxShadow: [
          BoxShadow(
            color: tokens.accent.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BlockIllustration(
                asset: AppAssets.blockCloud,
                size: 96,
                semanticLabel: '休息云朵',
              ),
              const SizedBox(width: AppSpacing.lg),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.brickPurple,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.md),
                  ),
                  border: Border.all(color: tokens.brickHighlight, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.hardShadow,
                      blurRadius: 0,
                      offset: const Offset(5, 5),
                    ),
                  ],
                ),
                child: const BlockIcon(AppAssets.rest, size: 52),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            dailyLimitReached ? '今天的观看时间到啦！' : '时间到啦，休息一下吧！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppFonts.pixelChinese,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dailyLimitReached
                ? '今日 $dailyLimit 次观看机会已全部使用完。'
                : '本轮观看时间已达上限，请稍作休息哦～',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: tokens.textSecondary),
          ),
          if (!dailyLimitReached) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimePart(value: hours, label: '小时'),
                const _TimeSeparator(),
                _TimePart(value: minutes, label: '分钟'),
                const _TimeSeparator(),
                _TimePart(value: seconds, label: '秒'),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceVariant,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(color: tokens.cardBorder, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BlockIcon(AppAssets.lock, size: 24),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  dailyLimitReached ? '今日观看已结束' : '休息结束后自动解锁',
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: onClose,
            icon: const BlockIcon(AppAssets.close, size: 26),
            label: const Text('关闭提示'),
          ),
        ],
      ),
    );
  }
}

class _TimePart extends StatelessWidget {
  const _TimePart({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.pixelLatin,
            fontSize: 44,
            height: 1,
            fontWeight: FontWeight.w900,
            color: tokens.brickYellow,
            shadows: [
              Shadow(color: tokens.hardShadow, offset: const Offset(3, 3)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TimeSeparator extends StatelessWidget {
  const _TimeSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 40,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: AppTokens.of(context).brickYellow,
        ),
      ),
    );
  }
}
