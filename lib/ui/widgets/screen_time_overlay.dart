import 'package:flutter/material.dart';

import '../../app/settings_controller.dart';
import '../../theme/app_tokens.dart';

class ScreenTimeOverlay extends StatelessWidget {
  const ScreenTimeOverlay({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    if (!settings.breakActive) {
      return const SizedBox.shrink();
    }

    final tokens = AppTokens.of(context);
    final remaining = settings.breakRemaining;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');

    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.76),
          child: Center(
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.all(AppSpacing.xl),
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: tokens.surface.withValues(alpha: 0.96),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.lg),
                ),
                border: Border.all(color: tokens.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.36),
                    blurRadius: 32,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppTokens.candyGradient,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppRadius.lg),
                      ),
                    ),
                    child: const Icon(
                      Icons.self_improvement,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '休息一下',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '本次观看时间已到，倒计时结束后才能继续操作。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    '$minutes:$seconds',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: tokens.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
