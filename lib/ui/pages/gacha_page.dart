import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/gacha/gacha_card.dart';
import '../../core/gacha/gacha_catalog.dart';
import '../../core/gacha/gacha_store.dart';
import '../../theme/app_assets.dart';
import '../../theme/app_tokens.dart';
import '../widgets/block_asset.dart';
import '../widgets/jelly_button.dart';
import '../widgets/section_header.dart';

class GachaPage extends StatefulWidget {
  const GachaPage({super.key});

  @override
  State<GachaPage> createState() => _GachaPageState();
}

class _GachaPageState extends State<GachaPage> with TickerProviderStateMixin {
  late final GachaStore _store;
  late final AnimationController _flipController;
  late final AnimationController _shineController;

  var _ownedCounts = <String, int>{};
  String? _lastDrawDate;
  var _bonusDraws = 0;
  var _pitySinceSsr = 0;
  GachaDrawResult? _lastResult;
  var _drawing = false;
  String? _error;

  bool get _drawnToday => _lastDrawDate == GachaStore.todayKey();
  bool get _canDraw => !_drawnToday || _bonusDraws > 0;

  @override
  void initState() {
    super.initState();
    _store = GachaStore();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _load();
  }

  void _load() {
    try {
      final snapshot = _store.load();
      _applySnapshot(snapshot);
    } catch (error) {
      _error = '读取卡包失败：$error';
    }
  }

  void _applySnapshot(GachaSnapshot snapshot) {
    _ownedCounts = snapshot.ownedCounts;
    _lastDrawDate = snapshot.lastDrawDate;
    _bonusDraws = snapshot.bonusDraws;
    _pitySinceSsr = snapshot.pitySinceSsr;
  }

  void _refreshFromStore() {
    if (!mounted || _drawing) {
      return;
    }
    try {
      final snapshot = _store.load();
      setState(() => _applySnapshot(snapshot));
    } catch (error) {
      setState(() => _error = '读取卡包失败：$error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFromStore());
  }

  @override
  void dispose() {
    _flipController.dispose();
    _shineController.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_drawing || !_canDraw) {
      return;
    }
    setState(() {
      _drawing = true;
      _error = null;
      _lastResult = null;
    });
    _flipController.reset();
    _shineController.reset();

    await _flipController.animateTo(
      0.48,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeIn,
    );
    if (!mounted) {
      return;
    }

    try {
      final pick = drawWithSsrPity(
        localGachaCatalog,
        math.Random(),
        pitySinceSsr: _pitySinceSsr,
      );
      final isNew = _store.recordDraw(
        pick.card,
        DateTime.now(),
        consumeBonusDraw: _drawnToday,
      );
      final snapshot = _store.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySnapshot(snapshot);
        _lastResult = GachaDrawResult(
          card: pick.card,
          isNew: isNew,
          guaranteed: pick.guaranteed,
        );
      });
      unawaited(_shineController.forward(from: 0));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '抽卡失败：$error';
      });
    }

    if (!mounted) {
      return;
    }
    await _flipController.animateTo(1, curve: Curves.easeOutBack);
    if (mounted) {
      setState(() => _drawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final owned = [
      for (final card in localGachaCatalog)
        if ((_ownedCounts[card.id] ?? 0) > 0)
          OwnedGachaCard(card: card, count: _ownedCounts[card.id]!),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (_error != null) ...[
                _StatusBanner(icon: Icons.error_outline, message: _error!),
                const SizedBox(height: AppSpacing.lg),
              ],
              _DrawPanel(
                result: _lastResult,
                drawnToday: _drawnToday,
                bonusDraws: _bonusDraws,
                pitySinceSsr: _pitySinceSsr,
                canDraw: _canDraw,
                drawing: _drawing,
                flipAnimation: _flipController,
                shineAnimation: _shineController,
                onDraw: _draw,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SectionHeader(
                title: '我的卡包',
                trailing: Text(
                  '已收集 ${owned.length} / ${localGachaCatalog.length}',
                  style: TextStyle(color: tokens.textSecondary),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (owned.isEmpty)
                _EmptyPack()
              else
                _OwnedGrid(ownedCards: owned),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DrawPanel extends StatelessWidget {
  const _DrawPanel({
    required this.result,
    required this.drawnToday,
    required this.bonusDraws,
    required this.pitySinceSsr,
    required this.canDraw,
    required this.drawing,
    required this.flipAnimation,
    required this.shineAnimation,
    required this.onDraw,
  });

  final GachaDrawResult? result;
  final bool drawnToday;
  final int bonusDraws;
  final int pitySinceSsr;
  final bool canDraw;
  final bool drawing;
  final Animation<double> flipAnimation;
  final Animation<double> shineAnimation;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final remainingToSsr = (7 - pitySinceSsr).clamp(1, 7);
    final status = drawnToday
        ? bonusDraws > 0
              ? '今日免费次数已用，还可使用 $bonusDraws 次额外抽卡。'
              : '今日已抽取，明天再来。'
        : '今日还有 1 次免费抽卡机会。';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        // 梦幻渐变：表面色打底，两端透出魔法紫光晕。
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tokens.brickPurple.withValues(alpha: 0.16),
            tokens.surface.withValues(alpha: 0.82),
            tokens.brickPurple.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: tokens.brickPurple, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: tokens.brickPurple.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 积木凸点装饰：右上角一排魔法紫圆钉。
          const Positioned(top: 0, right: 0, child: _BrickStuds()),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 780;
              final card = Center(
                child: _FlipCard(
                  result: result,
                  flipAnimation: flipAnimation,
                  shineAnimation: shineAnimation,
                ),
              );
              final info = _DrawInfo(
                status: status,
                drawnToday: drawnToday,
                bonusDraws: bonusDraws,
                remainingToSsr: remainingToSsr,
                canDraw: canDraw,
                drawing: drawing,
                result: result,
                onDraw: onDraw,
              );
              if (compact) {
                return Column(
                  children: [
                    card,
                    const SizedBox(height: AppSpacing.xl),
                    info,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: card),
                  const SizedBox(width: AppSpacing.xxl),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 面板角落的积木凸点：四枚魔法紫圆钉，带顶部高光描边。
class _BrickStuds extends StatelessWidget {
  const _BrickStuds();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(left: AppSpacing.xs),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.brickPurple.withValues(alpha: 0.75),
              border: Border.all(
                color: tokens.brickHighlight.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.hardShadow.withValues(alpha: 0.35),
                  blurRadius: 0,
                  offset: const Offset(1.5, 1.5),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DrawInfo extends StatelessWidget {
  const _DrawInfo({
    required this.status,
    required this.drawnToday,
    required this.bonusDraws,
    required this.remainingToSsr,
    required this.canDraw,
    required this.drawing,
    required this.result,
    required this.onDraw,
  });

  final String status;
  final bool drawnToday;
  final int bonusDraws;
  final int remainingToSsr;
  final bool canDraw;
  final bool drawing;
  final GachaDrawResult? result;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const BlockIcon(AppAssets.draw, size: 52),
            const SizedBox(width: AppSpacing.md),
            Text('今日抽卡', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(status, style: TextStyle(color: tokens.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _MiniBadge(icon: AppAssets.reward, label: '额外次数 $bonusDraws'),
            _MiniBadge(
              icon: AppAssets.star,
              label: '距 SSR 保底 $remainingToSsr 抽',
            ),
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _StatusBanner(
            icon: result!.isNew ? Icons.auto_awesome : Icons.copy_all_rounded,
            message:
                '${result!.guaranteed ? '保底触发，' : ''}${result!.isNew ? '获得新卡' : '获得重复卡'}：${result!.card.rarity.code} ${result!.card.name}',
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        JellyButton(
          icon: Icons.style_rounded,
          label: drawing
              ? '抽取中'
              : !canDraw
              ? '明天再抽'
              : '抽一张',
          tone: JellyTone.sunny,
          onPressed: !canDraw || drawing ? () {} : onDraw,
        ),
      ],
    );
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.result,
    required this.flipAnimation,
    required this.shineAnimation,
  });

  final GachaDrawResult? result;
  final Animation<double> flipAnimation;
  final Animation<double> shineAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: flipAnimation,
      builder: (context, _) {
        final angle = flipAnimation.value * math.pi;
        final showFront = flipAnimation.value >= 0.5;
        return AnimatedBuilder(
          animation: shineAnimation,
          builder: (context, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: showFront
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _CardFace(card: result?.card),
                        )
                      : const _QuestionCard(),
                ),
                if (shineAnimation.value > 0)
                  IgnorePointer(
                    child: Opacity(
                      opacity: (1 - shineAnimation.value).clamp(0, 1),
                      child: Transform.scale(
                        scale: 0.7 + shineAnimation.value * 1.4,
                        child: _ShineBurst(
                          ssr: result?.card.rarity == GachaRarity.ssr,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ShineBurst extends StatelessWidget {
  const _ShineBurst({required this.ssr});

  final bool ssr;

  @override
  Widget build(BuildContext context) {
    final color = ssr ? const Color(0xFFFFD54F) : AppTokens.cyanAccent;
    final size = ssr ? 260.0 : 190.0;
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.auto_awesome,
          size: size,
          color: color.withValues(alpha: 0.72),
        ),
        if (ssr) ...[
          Icon(
            Icons.star_rounded,
            size: 150,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          Positioned(
            top: 18,
            right: 10,
            child: Icon(Icons.auto_awesome, size: 56, color: color),
          ),
          Positioned(
            left: 12,
            bottom: 20,
            child: Icon(Icons.auto_awesome, size: 44, color: Colors.white),
          ),
        ],
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard();

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: 260,
      height: 360,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF65D4FF), Color(0xFF2F69E8)],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        boxShadow: [
          BoxShadow(
            color: AppTokens.candyGradient.last.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BlockIcon(AppAssets.treasure, size: 156),
            const SizedBox(height: AppSpacing.md),
            Text(
              '?',
              style: TextStyle(
                color: tokens.brickHighlight,
                fontFamily: AppFonts.pixelLatin,
                fontSize: 48,
                shadows: [
                  Shadow(color: tokens.hardShadow, offset: const Offset(3, 3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, this.compact = false});

  final GachaCard? card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actual = card ?? localGachaCatalog.first;
    final rarityColor = _rarityColor(actual.rarity);
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      onTap: () => _openCardPreview(context, actual),
      child: Container(
        width: compact ? 170 : 260,
        height: compact ? 236 : 360,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          border: Border.all(color: rarityColor, width: compact ? 2 : 3),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.22),
              blurRadius: compact ? 12 : 24,
              offset: Offset(0, compact ? 6 : 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          child: _CardArtwork(card: actual, rarityColor: rarityColor),
        ),
      ),
    );
  }
}

void _openCardPreview(BuildContext context, GachaCard card) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final tokens = AppTokens.of(dialogContext);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.lg),
                ),
                child: _CardArtwork(
                  card: card,
                  rarityColor: _rarityColor(card.rarity),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor: tokens.surface.withValues(alpha: 0.84),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CardArtwork extends StatelessWidget {
  const _CardArtwork({required this.card, required this.rarityColor});

  final GachaCard card;
  final Color rarityColor;

  @override
  Widget build(BuildContext context) {
    final asset = card.imageAsset;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withValues(alpha: 0.85),
            const Color(0xFFBDEBFF),
          ],
        ),
      ),
      child: asset == null
          ? _FallbackArtwork(card: card)
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _FallbackArtwork(card: card),
            ),
    );
  }
}

class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork({required this.card});

  final GachaCard card;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: 18,
          top: 22,
          child: Icon(
            Icons.star_rounded,
            size: 50,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 28,
          child: Icon(
            Icons.cloud_rounded,
            size: 64,
            color: Colors.white.withValues(alpha: 0.38),
          ),
        ),
        Icon(Icons.smart_toy_rounded, size: 82, color: Colors.white),
        Positioned(
          bottom: 12,
          child: Text(
            card.series,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnedGrid extends StatelessWidget {
  const _OwnedGrid({required this.ownedCards});

  final List<OwnedGachaCard> ownedCards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.lg,
      children: [
        for (final owned in ownedCards)
          Stack(
            children: [
              _CardFace(card: owned.card, compact: true),
              Positioned(
                right: AppSpacing.sm,
                top: AppSpacing.sm,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xDD17324F),
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.pill),
                      ),
                    ),
                    child: Text(
                      'x${owned.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _EmptyPack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.68),
        border: Border.all(color: tokens.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Row(
        children: [
          const BlockIllustration(
            asset: AppAssets.treasureBox,
            size: 120,
            semanticLabel: '积木宝箱',
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              '还没有卡片，点击上方问号卡开始抽取。',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant.withValues(alpha: 0.86),
        border: Border.all(color: tokens.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlockIcon.fromMaterial(icon, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(message, style: TextStyle(color: tokens.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceVariant.withValues(alpha: 0.68),
        border: Border.all(color: tokens.cardBorder),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlockIcon(icon, size: 22),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

Color _rarityColor(GachaRarity rarity) {
  return switch (rarity) {
    GachaRarity.c => const Color(0xFF7DB8FF),
    GachaRarity.b => const Color(0xFF46A6FF),
    GachaRarity.a => const Color(0xFF7C6CFF),
    GachaRarity.s => const Color(0xFFFF8A3D),
    GachaRarity.ssr => const Color(0xFFFFB338),
  };
}
