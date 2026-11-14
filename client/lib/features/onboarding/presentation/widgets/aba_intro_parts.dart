import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/kept_text.dart';

// ABA 소개 화면 부품: 머리(둥실 루미 · 제목 · 한 줄) · 원리 칸 2x2 · 보호자 민트 상자

/// 머리: 위아래로 둥실대는 루미 > 두 줄 제목 > 회색 한 줄
class AbaIntroHero extends StatelessWidget {
  const AbaIntroHero({super.key});

  /// 루미 그림 높이 (시안 기준 폭 393)
  static const _illustrationExtent = 64.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    return Column(
      children: [
        _BobbingIllustration(asset: AppAssets.abaIntroLumi, extent: _illustrationExtent.w),
        SizedBox(height: space.xs.h),
        // 줄바꿈은 문구의 \n 그대로 (언어마다 끊는 자리가 다름)
        Text(
          l10n.abaIntroTitle,
          textAlign: TextAlign.center,
          style: typo.libraryTitle.copyWith(color: colors.textPrimary, height: 1.25),
        ),
        SizedBox(height: (space.xs / 2).h),
        Text(
          l10n.abaIntroSubtitle,
          textAlign: TextAlign.center,
          style: typo.tileLabel.copyWith(color: colors.textSecondary, height: 1.3),
        ),
      ],
    );
  }
}

/// 원리 칸 2x2 (한 줄의 두 칸은 높이를 맞춤 · 긴 말은 칸 안에서 줄바꿈)
class AbaPrincipleGrid extends StatelessWidget {
  const AbaPrincipleGrid({super.key, required this.tiles});

  /// 칸 4개 (왼쪽 위 > 오른쪽 위 > 왼쪽 아래 > 오른쪽 아래)
  final List<Widget> tiles;

  /// 한 줄에 놓는 칸 수
  static const _columnCount = 2;

  @override
  Widget build(BuildContext context) {
    final gap = context.space.xs;
    final rows = [
      for (var start = 0; start < tiles.length; start += _columnCount)
        tiles.sublist(start, (start + _columnCount).clamp(0, tiles.length)),
    ];
    return Column(
      children: [
        for (final (rowIndex, row) in rows.indexed) ...[
          if (rowIndex > 0) SizedBox(height: gap.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, tile) in row.indexed) ...[
                  if (index > 0) SizedBox(width: gap.w),
                  Expanded(child: tile),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 원리 칸 하나: 왼쪽 위 그림 > 굵은 제목 > 회색 한 줄 (흰 판)
class AbaPrincipleTile extends StatelessWidget {
  const AbaPrincipleTile({super.key, required this.asset, required this.title, required this.body});

  final String asset;
  final String title;
  final String body;

  /// 칸 그림 크기 (시안 기준 폭 393)
  static const _iconExtent = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: space.sm.w, vertical: space.sm.h),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(color: colors.border, width: space.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(asset, width: _iconExtent.w, height: _iconExtent.w, excludeFromSemantics: true),
          SizedBox(height: space.xs.h),
          KeptText(title, style: typo.cardTitle.copyWith(color: colors.textPrimary, height: 1.2)),
          SizedBox(height: (space.xs / 2).h),
          KeptText(body, style: typo.bodySmall.copyWith(color: colors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }
}

/// 보호자 민트 상자: 굵은 제목 > 설명 (원리보다 보호자가 중심이라는 마무리)
class AbaGuardianNote extends StatelessWidget {
  const AbaGuardianNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: space.md.w, vertical: space.sm.h),
      decoration: BoxDecoration(
        color: colors.goalSelectedFill,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeptText(l10n.abaIntroGuardianTitle, style: typo.sectionTitle.copyWith(color: colors.textPrimary, height: 1.3)),
          SizedBox(height: (space.xs / 2).h),
          KeptText(l10n.abaIntroGuardianBody, style: typo.bodySmall.copyWith(color: colors.textPrimary, height: 1.4)),
        ],
      ),
    );
  }
}

/// 위아래로 천천히 둥실대는 그림 (기기 "동작 줄이기"면 멈춤)
class _BobbingIllustration extends StatefulWidget {
  const _BobbingIllustration({required this.asset, required this.extent});

  final String asset;
  final double extent;

  @override
  State<_BobbingIllustration> createState() => _BobbingIllustrationState();
}

class _BobbingIllustrationState extends State<_BobbingIllustration> with SingleTickerProviderStateMixin {
  /// 둥실 높이 (논리 px)
  static const _bobAmplitude = 6.0;

  // 한 번 오르고 내리는 데 float 한 주기 (오르기 > 내리기 반복)
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppMotion.float);
  late final Animation<double> _lift = CurvedAnimation(parent: _controller, curve: AppMotion.standard);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isMotionReduced = MediaQuery.disableAnimationsOf(context);
    if (isMotionReduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(widget.asset, height: widget.extent, fit: BoxFit.contain, excludeFromSemantics: true);
    return AnimatedBuilder(
      animation: _lift,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, -_bobAmplitude * _lift.value), child: child),
      child: image,
    );
  }
}
