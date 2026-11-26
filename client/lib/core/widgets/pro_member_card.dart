import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';

/// Pro 회원 카드 재질: 금빛 그라데이션 판 + 테두리 + 그림자 + 오른쪽 위 둥근 빛, [hasShineSweep] 이면 빛 띠가 한 번 지나감
///
/// 내 정보 내 요금제 카드 · 내 요금제 시트 머리가 같이 씀 (금빛 토큰 `proPlanMyCard*` 를 화면마다 따로 조합하지 않게, #1516)
class ProMemberCardSurface extends StatelessWidget {
  const ProMemberCardSurface({super.key, required this.child, this.hasShineSweep = false});

  final Widget child;

  /// 뜰 때 빛 띠가 왼쪽 위 > 오른쪽 아래로 한 번 지나가는가 (동작 줄이기면 없음)
  final bool hasShineSweep;

  /// 그림자 아래 6 · 번짐 18
  static const _shadowOffsetY = 6.0;
  static const _shadowBlur = 18.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(context.space.cardRadius.r);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.proPlanMyCardStart, colors.proPlanMyCardEnd],
        ),
        borderRadius: radius,
        border: Border.all(color: colors.proPlanMyCardBorder),
        boxShadow: [
          BoxShadow(
            color: colors.proPlanMyCardShadow,
            offset: Offset(0, _shadowOffsetY.h),
            blurRadius: _shadowBlur.r,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            const _CornerGlow(),
            child,
            if (hasShineSweep) const Positioned.fill(child: _ShineSweep()),
          ],
        ),
      ),
    );
  }
}

/// 오른쪽 위 큰 둥근 빛 (회원 카드 광택, 카드 밖은 잘림)
class _CornerGlow extends StatelessWidget {
  const _CornerGlow();

  /// 지름 · 카드 모서리 밖으로 나간 정도 · 투명도
  static const _size = 180.0;
  static const _overflow = 60.0;
  static const _opacity = 0.5;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -_overflow.w,
      right: -_overflow.w,
      child: IgnorePointer(
        child: Opacity(
          opacity: _opacity,
          child: Container(
            width: _size.w,
            height: _size.w,
            decoration: BoxDecoration(color: context.colors.proPlanMyCardHalo, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// 카드 위 빛 띠 한 번: 판이 자리 잡은 뒤([AppMotion.slow]) 왼쪽 위 > 오른쪽 아래 ([AppMotion.shineSweep])
/// 지연은 Timer 가 아니라 타임라인 앞 구간을 비움 > dispose 뒤 콜백 없음
class _ShineSweep extends StatefulWidget {
  const _ShineSweep();

  @override
  State<_ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<_ShineSweep> with SingleTickerProviderStateMixin {
  /// 빛 띠 폭의 절반 (그라데이션 정지점 비율)
  static const _bandHalfWidth = 0.14;

  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final total = AppMotion.slow + AppMotion.shineSweep;
    _controller = AnimationController(vsync: this, duration: total)..forward();
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(AppMotion.slow.inMicroseconds / total.inMicroseconds, 1, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.isReducedMotionOf(context)) return const SizedBox.shrink();
    final light = context.colors.proPlanMyCardHalo;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final sweepProgress = _progress.value;
          // 시작 전 · 다 지나간 뒤에는 그리지 않음
          if (sweepProgress <= 0 || sweepProgress >= 1) return const SizedBox.shrink();
          // 띠 가운데가 판 밖(-폭) > 판 밖(1+폭)으로 이동
          final center = -_bandHalfWidth + (1 + 2 * _bandHalfWidth) * sweepProgress;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [light.withValues(alpha: 0), light, light.withValues(alpha: 0)],
                stops: [
                  (center - _bandHalfWidth).clamp(0.0, 1.0),
                  center.clamp(0.0, 1.0),
                  (center + _bandHalfWidth).clamp(0.0, 1.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pro 회원 카드 혜택 알약: 체크 + 짧은 문장 (길면 알약 안에서 줄을 바꿈)
class ProMemberBenefitPill extends StatelessWidget {
  const ProMemberBenefitPill({super.key, required this.label});

  final String label;

  /// 알약 사이 (가로 · 세로)
  static const gap = 6.0;

  static const _padH = 10.0;
  static const _padV = 6.0;
  static const _checkSize = 10.0;
  static const _checkToLabel = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 체크는 글자 배율을 따라 커짐 (큰 글자에서 점처럼 작아지지 않게)
    final checkSize = MediaQuery.textScalerOf(context).scale(_checkSize.w);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
      decoration: BoxDecoration(
        color: colors.proPlanMyCardPillFill,
        borderRadius: BorderRadius.circular(context.space.pillRadius.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            AppAssets.iconCheck,
            width: checkSize,
            height: checkSize,
            colorFilter: ColorFilter.mode(colors.proPlanMyCardPillCheck, BlendMode.srcIn),
            excludeFromSemantics: true,
          ),
          SizedBox(width: _checkToLabel.w),
          Flexible(
            child: Text(
              label,
              style: context.typo.proPlanBenefitDetail.copyWith(color: colors.proPlanMyCardPillText),
            ),
          ),
        ],
      ),
    );
  }
}
