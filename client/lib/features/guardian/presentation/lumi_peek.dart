import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/assets/app_assets.dart';
import '../domain/routine_stage.dart';

/// 화면 옆에서 나타나 손을 흔들고 다시 숨는 루미 (Figma `Group 26`).
///
/// 기다리는 동안 화면이 정지해 보이지 않게 하는 장치다. 계속 흔들면 시선을
/// 뺏으므로 **나왔다 → 흔들고 → 들어간 뒤 쉰다**를 반복한다.
///
/// **좌우 양쪽에 쓰인다.** 준비 화면(262:4569)은 왼쪽 x=-48,
/// 생성 화면(262:4703)은 오른쪽 x=325다. 정지 시안이라 등장·퇴장은 그리지
/// 않았지만, 그 위치가 "옆에서 빼꼼 내민" 상태다. 방향만 다르고 연출은 같아
/// 화면을 둘로 나누지 않고 [side]로 받는다.
class LumiPeek extends StatefulWidget {
  const LumiPeek({super.key, required this.side});

  /// 어느 쪽에서 나오는가
  final LumiSide side;

  @override
  State<LumiPeek> createState() => _LumiPeekState();
}

class _LumiPeekState extends State<LumiPeek>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 한 번 나왔다 들어가는 데 걸리는 시간. 쉬는 구간까지 포함한다.
  static const _cycle = Duration(milliseconds: 5200);

  /// 그림이 **화면에서 차지하는 자리** — 에셋 크기 그대로다.
  ///
  /// **덤프의 그룹 크기(122×123)를 쓰면 안 된다.** `Group 26` 상자에는 그려지지
  /// 않는 여백이 붙어 있어, 그 크기로 늘리면 몸이 시안보다 아홉 넓고 자리도
  /// 어긋난다. 시안 export 위에 에셋을 겹쳐 맞춰 잰 값이다.
  static const _width = 113.0;
  static const _height = 99.0;

  /// 화면 밖으로 걸치는 정도 — **좌우가 다르다.**
  /// 시안에서 왼쪽 루미는 x=-31이고, 오른쪽은 오른끝이 430이라 37이 잘린다.
  static const _peekInsetLeft = 31.0;
  static const _peekInsetRight = 37.0;

  /// 다 나왔을 때 화면 안쪽으로 들어온 거리 (부호는 [_direction]이 준다)
  double get _restX =>
      -(widget.side == LumiSide.left ? _peekInsetLeft : _peekInsetRight);

  /// 숨을 때는 완전히 가려질 만큼 더 빠진다
  double get _hiddenX => -_width;

  /// 오른쪽이면 이동 부호를 뒤집는다. `Align`이 기준 모서리를 잡아주므로
  /// 여기서는 "바깥으로 얼마나 나가는가"만 다루면 된다.
  double get _direction => widget.side == LumiSide.left ? 1 : -1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 등장(0~15%) → 흔들기(15~65%) → 퇴장(65~80%) → 쉼(80~100%).
  ///
  /// 시간 비율로 나눈 이유 — 컨트롤러 하나로 전체를 돌리면 중간에 화면이
  /// 사라져도 상태가 어긋나지 않는다.
  double _slideX(double t) {
    if (t < 0.15) {
      return _lerp(_hiddenX, _restX, Curves.easeOutBack.transform(t / 0.15));
    }
    if (t < 0.65) return _restX;
    if (t < 0.80) {
      return _lerp(
        _restX,
        _hiddenX,
        Curves.easeInCubic.transform((t - 0.65) / 0.15),
      );
    }
    return _hiddenX;
  }

  /// 팔 흔들기 — 다 나온 뒤에만 흔든다. 나오면서 흔들면 어수선하다.
  double _armAngle(double t) {
    if (t < 0.18 || t > 0.62) return 0;
    final progress = (t - 0.18) / (0.62 - 0.18);
    // 2.5번 왕복. 끝에서 부드럽게 멎도록 진폭을 점점 줄인다.
    final decay = 1 - progress;
    return math.sin(progress * math.pi * 5) * 0.22 * decay;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.side == LumiSide.left;

    // 세로 위치는 부모 [Positioned]가 잡는다. 여기선 가로 이동만 맡는다.
    // 부모가 left·right를 모두 0으로 주므로 어느 모서리에 붙일지 정해야 한다.
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Transform.translate(
            // Figma 좌표(393 폭 기준)를 기기 폭에 맞춰 환산한다.
            // 오른쪽이면 같은 거리를 반대로 밀어 대칭을 만든다.
            offset: Offset((_slideX(t) * _direction).w, 0),
            child: Transform.rotate(
              // 몸 전체를 살짝 기울여 손 흔드는 느낌을 낸다.
              // SVG가 통짜라 팔만 따로 돌릴 수 없다.
              angle: _armAngle(t) * _direction,
              // 발치를 축으로 삼아야 몸이 붕 뜨지 않는다
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          );
        },
        // 오른쪽 루미는 좌우를 뒤집는다 — Figma 262:4703이 거울상이다.
        // 뒤집지 않으면 얼굴이 화면 밖을 보게 된다.
        child: Transform.flip(
          flipX: !isLeft,
          // **PNG다.** 더듬이 빛이 `<filter>`라 SVG로 두면 통째로 사라진다.
          child: Image.asset(
            AppAssets.lumiThinking,
            width: _width.w,
            height: _height.h,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
