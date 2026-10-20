import 'package:flutter/material.dart';

/// 말풍선 글을 어느 쪽에 맞출지.
enum CoachMarkAlign { center, end }

/// 코치마크 한 단계 — 무엇을 가리키고 뭐라고 말하는가.
class CoachMarkStep {
  const CoachMarkStep({
    required this.target,
    required this.message,
    this.align = CoachMarkAlign.center,
    this.holePadding = EdgeInsets.zero,
    this.holeRadius = 0,
    this.feather = 0,
    this.bleedLeft = false,
    this.pointerAt = 0.5,
    this.pointerGap = 0,
    this.partsOf,
    this.partRadius = 0,
    this.demoBuilder,
  });

  /// 가리킬 위젯. 화면에 그려져 있어야 잴 수 있다.
  final GlobalKey target;

  /// 말풍선 글. `*강조*` 로 감싼 부분은 강조색으로 나온다.
  final String message;

  final CoachMarkAlign align;

  /// 대상보다 구멍을 얼마나 키울지.
  final EdgeInsets holePadding;
  final double holeRadius;

  /// 가장자리를 풀어 줄 정도 — 대상이 빛나면(글로우) 준다.
  final double feather;

  /// 구멍을 화면 왼쪽 끝까지 넓힌다. 밀려 나간 카드가 화면 가장자리에서 잘려 보이는 자리다
  /// (시안 1291:10401).
  final bool bleedLeft;

  /// 화살표가 대상 가로의 어디를 가리키는가(0~1). 밀어서 열린 줄은 버튼 쪽을 가리킨다.
  final double pointerAt;

  /// 구멍 가장자리에서 화살표가 시작하기까지 띄울 거리 (시안 1291:10730 은 배지에서 3 떨어진다).
  final double pointerGap;

  /// 대상 안에서 실제로 밝을 모양들. 대상 상자를 받아 돌려준다. 없으면 상자 전체가 밝다.
  final List<Rect> Function(Rect target)? partsOf;
  final double partRadius;

  /// 구멍 위에 얹는 시범 층 (손가락·시트 미리보기 등). 구멍이 자리를 잡은 뒤에 그려지고
  /// 터치는 막지 않는다. 대상 상자를 받아 **`Positioned` 를 돌려준다.** 없으면 그리지 않는다.
  final Widget Function(BuildContext context, Rect targetRect)? demoBuilder;
}
