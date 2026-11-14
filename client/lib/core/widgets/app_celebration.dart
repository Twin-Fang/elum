import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../haptics/tap_haptics.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'kept_text.dart';

/// 보상 축하 게이지 값: 이전 > 이후 (최대값 기준 비율로 차오름)
class AppCelebrationGauge {
  const AppCelebrationGauge({
    required this.before,
    required this.after,
    required this.maximum,
    required this.valueFormat,
  });

  final int before;
  final int after;

  /// 게이지 가득 찬 값 (0 이하면 가득 찬 것으로 봄)
  final int maximum;

  /// 숫자 > 화면 글 (l10n 문구 함수, 예: `3일`)
  final String Function(int value) valueFormat;

  double fractionOf(double value) => maximum <= 0 ? 1 : (value / maximum).clamp(0.0, 1.0);
}

/// 보상 축하 장면: 그림 튐 > 뒤 빛 번짐·그림 위 빛 쓸기 > 제목 · 이유 한 줄 > 이전 → 이후 게이지
/// 등장 순간 햅틱 한 번. 동작 줄이기면 연출 없이 끝 모습 (햅틱은 그대로)
/// 창·시트·화면 어디든 넣는 본문 부품이라 버튼은 부르는 쪽이 둠
class AppCelebration extends StatefulWidget {
  const AppCelebration({
    super.key,
    required this.illustrationAsset,
    required this.title,
    required this.reasonText,
    this.gauge,
  });

  /// 축하 3D 그림 PNG (AppAssets.celebration*)
  final String illustrationAsset;
  final String title;

  /// 왜 받았는지 한 줄
  final String reasonText;

  /// null 이면 게이지 없음
  final AppCelebrationGauge? gauge;

  @override
  State<AppCelebration> createState() => _AppCelebrationState();
}

class _AppCelebrationState extends State<AppCelebration> with SingleTickerProviderStateMixin {
  // 구간 4개 ([AppMotion.celebrationSequence] 기준 비율): 그림 튐 · 빛 · 글 · 게이지
  static const _popInterval = Interval(0, 0.35, curve: AppMotion.springPop);
  static const _popOpacityInterval = Interval(0, 0.15);
  static const _glowInterval = Interval(0.12, 0.6, curve: AppMotion.decelerate);
  static const _sweepInterval = Interval(0.25, 0.6, curve: AppMotion.standard);
  static const _titleInterval = Interval(0.2, 0.4, curve: AppMotion.entry);
  static const _reasonInterval = Interval(0.38, 0.58, curve: AppMotion.entry);
  static const _gaugeInterval = Interval(0.55, 1, curve: AppMotion.decelerate);

  /// 그림 크기 · 뒤 빛 지름 (그림 대비)
  static const _illustrationSize = 160.0;
  static const _glowScaleStart = 0.6;
  static const _glowScaleEnd = 1.2;

  /// 빛이 다 번진 뒤 남는 세기 (끝 모습에서도 은은하게)
  static const _glowRestOpacity = 0.6;

  /// 그림 위 빛 띠 세기 · 폭 (그라데이션 정지점 비율)
  static const _sweepOpacity = 0.55;
  static const _sweepHalfWidth = 0.12;

  /// 글이 올라오는 거리
  static const _textSlide = 8.0;

  /// 게이지 높이
  static const _gaugeHeight = 10.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.celebrationSequence,
  );
  bool _hasStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasStarted) return;
    _hasStarted = true;
    playCelebrationHaptic();
    if (AppMotion.isReducedMotionOf(context)) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _at(Interval interval) => interval.transform(_controller.value);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _illustrationWithGlow(context),
          SizedBox(height: context.space.md.h),
          _fadeUp(_at(_titleInterval), _title(context)),
          SizedBox(height: context.space.xs.h),
          _fadeUp(_at(_reasonInterval), _reason(context)),
          if (widget.gauge != null) ...[
            SizedBox(height: context.space.md.h),
            _fadeUp(_at(_reasonInterval), _gaugeRow(context, widget.gauge!)),
          ],
        ],
      ),
    );
  }

  /// 그림 + 뒤 빛 원 + 그림 위 빛 띠
  Widget _illustrationWithGlow(BuildContext context) {
    final size = _illustrationSize.w;
    final glowProgress = _at(_glowInterval);
    // 빛: 0 > 1 로 번졌다가 남는 세기로 가라앉음
    final glowOpacity = glowProgress < 0.5 ? glowProgress * 2 : lerpDouble(1, _glowRestOpacity, (glowProgress - 0.5) * 2)!;
    final glowScale = lerpDouble(_glowScaleStart, _glowScaleEnd, glowProgress)!;
    final popScale = lerpDouble(AppMotion.popInStartScale, 1, _at(_popInterval))!;
    return SizedBox(
      width: size * _glowScaleEnd,
      height: size * _glowScaleEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: glowScale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.colors.celebrationGlow.withValues(alpha: context.colors.celebrationGlow.a * glowOpacity),
                    context.colors.celebrationGlow.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Opacity(
            opacity: _at(_popOpacityInterval),
            child: Transform.scale(scale: popScale, child: _sweptIllustration(context, size)),
          ),
        ],
      ),
    );
  }

  /// 빛 띠가 왼쪽 위 > 오른쪽 아래로 한 번 지나감 (그림이 있는 자리에만)
  Widget _sweptIllustration(BuildContext context, double size) {
    final image = Image.asset(
      widget.illustrationAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    final sweep = _sweepInterval.transform(_controller.value);
    if (sweep <= 0 || sweep >= 1) return image;
    final center = lerpDouble(-_sweepHalfWidth, 1 + _sweepHalfWidth, sweep)!;
    final light = context.colors.surface;
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          light.withValues(alpha: 0),
          light.withValues(alpha: _sweepOpacity),
          light.withValues(alpha: 0),
        ],
        stops: [
          (center - _sweepHalfWidth).clamp(0.0, 1.0),
          center.clamp(0.0, 1.0),
          (center + _sweepHalfWidth).clamp(0.0, 1.0),
        ],
      ).createShader(bounds),
      child: image,
    );
  }

  Widget _title(BuildContext context) => Text(
    widget.title,
    textAlign: TextAlign.center,
    style: context.typo.dialogTitle.copyWith(color: context.colors.textPrimary, fontWeight: FontWeight.w700),
  );

  Widget _reason(BuildContext context) => KeptText(
    widget.reasonText,
    textAlign: TextAlign.center,
    style: context.typo.creditBody.copyWith(color: context.colors.textSecondary),
  );

  /// 이전 → 지금 숫자 (게이지와 같은 진행으로 셈) + 차오르는 막대
  Widget _gaugeRow(BuildContext context, AppCelebrationGauge gauge) {
    final colors = context.colors;
    final value = lerpDouble(gauge.before.toDouble(), gauge.after.toDouble(), _at(_gaugeInterval))!;
    final numberStyle = context.typo.creditTitle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gauge.valueFormat(gauge.before), style: numberStyle.copyWith(color: colors.textSecondary)),
            SizedBox(width: context.space.xs.w),
            Text('→', style: numberStyle.copyWith(color: colors.textSecondary)), // l10n-ignore: 기호
            SizedBox(width: context.space.xs.w),
            Text(gauge.valueFormat(value.round()), style: numberStyle.copyWith(color: colors.celebrationGaugeFill)),
          ],
        ),
        SizedBox(height: context.space.xs.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(context.space.pillRadius),
          // 폭은 부모 폭 가득 (빈 칸 · 찬 칸이 같은 길이 기준)
          child: SizedBox(
            width: double.infinity,
            height: _gaugeHeight.h,
            child: Stack(
              children: [
                Positioned.fill(child: ColoredBox(color: colors.celebrationGaugeTrack)),
                FractionallySizedBox(
                  widthFactor: gauge.fractionOf(value),
                  heightFactor: 1,
                  child: ColoredBox(color: colors.celebrationGaugeFill),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 투명 > 불투명 + 아래 8px > 제자리
  Widget _fadeUp(double progress, Widget child) {
    if (progress >= 1) return child;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, _textSlide * (1 - progress)), child: child),
    );
  }
}
