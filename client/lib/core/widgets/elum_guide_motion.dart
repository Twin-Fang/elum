import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';

// 안내 창·시트 움직임 부품: 그림 · 받는 순간 그림(튀어 오름 > 둥실) · 세며 바뀌는 숫자
// 시간·곡선은 AppMotion 토큰만, 기기 "동작 줄이기"면 모두 바로 끝 모습

/// 그림 크기 2단계: 창 96 · 시트 120
enum ElumGuideIllustrationSize {
  dialog(96),
  sheet(120);

  const ElumGuideIllustrationSize(this.extent);

  final double extent;
}

/// 맨 위 그림 (루미 · 크레딧 PNG)
class ElumGuideIllustration extends StatelessWidget {
  const ElumGuideIllustration({super.key, required this.asset, required this.size});

  final String asset;
  final ElumGuideIllustrationSize size;

  @override
  Widget build(BuildContext context) =>
      Image.asset(asset, height: size.extent.w, fit: BoxFit.contain, excludeFromSemantics: true);
}

/// 받는 순간 그림: 튀어 오름 > 위아래로 둥실 2번 (점점 작게) 뒤 멈춤 + 아래 `+N` 이 0 에서 세며 올라감
class ElumGuideRewardIllustration extends StatefulWidget {
  const ElumGuideRewardIllustration({super.key, required this.asset, required this.amount});

  final String asset;

  /// 받은 수 (0 이면 `+N` 줄 없음)
  final int amount;

  @override
  State<ElumGuideRewardIllustration> createState() => _ElumGuideRewardIllustrationState();
}

class _ElumGuideRewardIllustrationState extends State<ElumGuideRewardIllustration> with TickerProviderStateMixin {
  /// 둥실 높이 · 횟수
  static const _floatAmplitude = 4.0;
  static const _floatCycles = 2;

  late final AnimationController _pop = AnimationController(vsync: this, duration: AppMotion.celebrationEntrance);
  late final AnimationController _float = AnimationController(vsync: this, duration: AppMotion.float);
  late final Animation<double> _popScale = CurvedAnimation(parent: _pop, curve: AppMotion.springOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pop.isAnimating || _pop.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = 1;
      return;
    }
    // 튀어 오름 다음 둥실 (한 번만)
    _pop.forward().whenComplete(() {
      if (mounted) _float.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 반짝임이 둘레에 퍼진 큰 그림이라 시트 크기로 (창 안에서도 주인공)
    final extent = ElumGuideIllustrationSize.sheet.extent.w;
    final image = Image.asset(widget.asset, height: extent, fit: BoxFit.contain, excludeFromSemantics: true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_pop, _float]),
          builder: (context, child) {
            final t = _float.value;
            // 사인 2주기, 끝으로 갈수록 작아져 제자리에서 멈춤
            final dy = -math.sin(t * math.pi * 2 * _floatCycles) * _floatAmplitude * (1 - t);
            return Transform.translate(
              offset: Offset(0, dy.h),
              child: Transform.scale(scale: _popScale.value, child: child),
            );
          },
          child: image,
        ),
        if (widget.amount > 0)
          ElumGuideCountUpText(
            from: 0,
            to: widget.amount,
            format: context.l10n.creditRewardPlus,
            style: context.typo.creditNumber.copyWith(color: context.colors.creditNumberText),
          ),
      ],
    );
  }
}

/// [from] > [to] 로 세며 바뀌는 숫자 글 (값 변화 시간 · 감속 곡선)
class ElumGuideCountUpText extends StatelessWidget {
  const ElumGuideCountUpText({
    super.key,
    required this.from,
    required this.to,
    required this.format,
    required this.style,
  });

  final int from;
  final int to;
  final String Function(int value) format;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) || from == to) return Text(format(to), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from.toDouble(), end: to.toDouble()),
      duration: AppMotion.valueChange,
      curve: AppMotion.decelerate,
      builder: (context, value, _) => Text(format(value.round()), style: style),
    );
  }
}
