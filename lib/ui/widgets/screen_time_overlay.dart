import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/settings_controller.dart';
import '../../theme/app_tokens.dart';

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

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: ClipRect(
          // Frosted daylight wash over the whole app, per the design mock:
          // the content stays visible but bright, blurred and untouchable.
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB8F3EDFF), Color(0xC2E4D9FF)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        const Positioned(
                          top: -26,
                          right: 26,
                          child: Icon(
                            Icons.nightlight_round,
                            color: Color(0xFFFFD97A),
                            size: 44,
                          ),
                        ),
                        const Positioned(
                          top: -6,
                          left: 10,
                          child: Icon(
                            Icons.auto_awesome,
                            color: Color(0xFFB79BFF),
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
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A6A9E),
                      ),
                    ),
                  ],
                ),
              ),
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
    return Container(
      width: 520,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      padding: const EdgeInsets.fromLTRB(40, 44, 40, 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF4EDFF)],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(36)),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B7BFF).withValues(alpha: 0.35),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAD8FF),
              borderRadius: const BorderRadius.all(Radius.circular(26)),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Icon(
              dailyLimitReached ? Icons.bedtime_rounded : Icons.alarm_rounded,
              color: Color(0xFFA06BFF),
              size: 40,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            dailyLimitReached ? '今天的观看时间到啦！' : '时间到啦，休息一下吧！',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF7D5BE8),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dailyLimitReached
                ? '今日 $dailyLimit 次观看机会已全部使用完。'
                : '本轮观看时间已达上限，请稍作休息哦～',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF8C82A6)),
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
            decoration: const BoxDecoration(
              color: Color(0xFFE9DDFF),
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Color(0xFF8F66F2),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  dailyLimitReached ? '今日观看已结束' : '休息结束后自动解锁',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8F66F2),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
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
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 44,
            height: 1,
            fontWeight: FontWeight.w900,
            color: Color(0xFF9A73FF),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9A73FF),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 40,
          height: 1.1,
          fontWeight: FontWeight.w900,
          color: Color(0xFFB18EFF),
        ),
      ),
    );
  }
}
