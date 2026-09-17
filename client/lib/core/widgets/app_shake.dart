import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_motion.dart';

/// [trigger] 값이 바뀔 때마다 자식을 좌우로 한 번 흔든다.
///
/// 잘못된 입력을 붉은색이나 경고 아이콘 없이 알리는 수단이다. 이 서비스는
/// 보호자와 아동이 함께 쓰므로 실패를 질책처럼 보이게 하지 않는다 (docs/motion.md).
///
/// OS "동작 줄이기"가 켜져 있으면 흔들지 않는다 — 전정기관 감각이 예민한
/// 사용자에게 흔들림은 불쾌감을 준다. 이때는 흔들림 없이 그대로 둔다.
class AppShake extends StatefulWidget {
  const AppShake({super.key, required this.trigger, required this.child});

  /// 값이 이전과 달라지면 흔든다. 보통 실패 횟수를 넘긴다.
  final int trigger;

  final Widget child;

  @override
  State<AppShake> createState() => _AppShakeState();
}

class _AppShakeState extends State<AppShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shake,
  );

  @override
  void didUpdateWidget(AppShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger == old.trigger) return;
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
        // 좌우로 두 번 왕복하고 점점 잦아든다. sin 두 주기에 (1-t)를 곱해
        // 끝에서 정확히 0으로 돌아오게 한다 — 남아 있으면 위치가 틀어진다.
        final t = _controller.value;
        final decay = 1 - t;
        final offset =
            AppMotion.shakeAmplitude * decay * _wave(t);
        return Transform.translate(offset: Offset(offset.w, 0), child: child);
      },
      child: widget.child,
    );
  }

  /// 0→1 구간에서 좌우 두 왕복. 시작과 끝이 모두 0이다.
  double _wave(double t) {
    const cycles = 2;
    return -math.sin(2 * math.pi * cycles * t);
  }

}
