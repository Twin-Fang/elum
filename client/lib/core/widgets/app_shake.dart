import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_motion.dart';

/// [trigger] 값이 바뀌면 자식을 한 번 흔들어 잘못된 입력을 알린다.
///
/// 붉은색이나 경고 아이콘을 쓰지 않는다. 이 앱은 보호자와 아이가 함께 보는
/// 화면이고, 실패가 질책처럼 읽히면 안 된다 (docs/motion.md).
///
/// ## 왜 등폭이 아니라 감쇠인가
///
/// 같은 폭으로 같은 횟수를 흔들면 기계가 튕기는 것처럼 보인다. 손으로 건드린
/// 물체는 첫 흔들림이 가장 크고 이후 절반씩 잦아들며 멎는다. 그 감쇠를 그대로 쓴다.
///
/// ```
///   offset(t) = A · e^(−λt) · sin(2π·c·t)
/// ```
///
/// | 기호 | 값 | 이유 |
/// |---|---|---|
/// | `c` (주기) | 2.5 | 0.5의 배수여야 시작과 끝이 모두 0이다. 어긋나면 위치가 틀어진 채 굳는다 |
/// | `λ` (감쇠) | 3.5 | 스윙이 매번 정확히 절반으로 줄어든다 — 7.2 → 3.6 → 1.8 → 0.9px |
/// | `A` (진폭) | 10 | 지수 때문에 실제 첫 스윙은 7px대다. 점 지름(20)의 3분의 1 남짓 |
///
/// 뒤쪽 두 스윙은 1px 아래라 눈에 잡히기보다 여운으로 남는다. 그게 "털고 멎는"
/// 인상을 만든다.
///
/// OS "동작 줄이기"가 켜져 있으면 흔들지 않는다 — 전정기관이 예민한 사용자에게
/// 흔들림은 불쾌감을 준다. 이때도 햅틱은 남겨 실패 사실 자체는 전달한다.
class AppShake extends StatefulWidget {
  const AppShake({
    super.key,
    required this.trigger,
    required this.child,
    this.haptic = true,
  });

  /// 값이 이전과 달라지면 흔든다. 보통 실패 횟수를 넘긴다.
  final int trigger;

  /// 흔들 때 가벼운 진동을 함께 줄지. 소리 없는 환경에서 실패를 알리는 통로다.
  final bool haptic;

  final Widget child;

  @override
  State<AppShake> createState() => _AppShakeState();
}

class _AppShakeState extends State<AppShake>
    with SingleTickerProviderStateMixin {
  /// 시작과 끝이 모두 0이 되는 주기 수. 0.5 단위로만 바꾼다.
  static const _cycles = 2.5;

  /// 스윙이 절반씩 줄어드는 감쇠 계수.
  static const _damping = 3.5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
  );

  @override
  void didUpdateWidget(AppShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger == old.trigger) return;

    if (widget.haptic) HapticFeedback.lightImpact();
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 멈춰 있을 때는 변환을 걸지 않는다.
        //
        // 지수 감쇠는 끝에서 수학적으로만 0에 가까울 뿐 정확히 0이 아니다
        // (sin(5π)의 부동소수점 오차 × e^-3.5 ≈ 1e-17). 눈에 보이진 않지만
        // 그대로 두면 위젯이 영원히 미세하게 어긋난 자리에 남는다.
        if (!_controller.isAnimating) return child!;

        final t = _controller.value;
        final dx = AppMotion.shakeAmplitude *
            math.exp(-_damping * t) *
            math.sin(2 * math.pi * _cycles * t);
        return Transform.translate(offset: Offset(dx.w, 0), child: child);
      },
      child: widget.child,
    );
  }
}
