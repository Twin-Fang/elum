import 'package:flutter/animation.dart';

/// 모션 토큰 — duration·curve의 단일 출처.
///
/// **화면에서 `Duration(milliseconds: 250)` 같은 숫자를 직접 쓰지 않는다.**
/// 값이 흩어지면 나중에 톤을 바꿀 때 grep으로도 못 찾는다.
/// 상세 근거는 docs/motion.md 참조.
///
/// ⚠️ Timer·debounce처럼 **애니메이션이 아닌 Duration**은 여기 두지 않는다.
/// (예: SetupDoneScreen.holdDuration — 화면 체류 시간이지 모션이 아니다)
abstract final class AppMotion {
  // --- Duration ---
  // 업계 기준(Material·NN/g)은 100~300ms, 복잡한 것도 500ms를 넘기지 않는다.
  // "눈에 잡힐 만큼 길되, 흐름을 방해하지 않을 만큼 짧게."

  /// 터치 피드백
  static const instant = Duration(milliseconds: 100);

  /// 기본 UI 전환·선택 상태 변경
  static const fast = Duration(milliseconds: 200);

  /// 카드·리스트 등장, 상태 변경
  static const normal = Duration(milliseconds: 300);

  /// 페이지 전환, 모달 등장
  static const slow = Duration(milliseconds: 400);

  /// 온보딩·특수 진입
  static const emphasis = Duration(milliseconds: 500);

  /// 은은하게 떠다니는(floating) 반복 연출 한 주기.
  /// 등장 연출과 겹치지 않도록 충분히 느리게 잡는다.
  static const float = Duration(milliseconds: 2400);

  // --- Curve ---

  /// 일반 상태 변화
  static const standard = Curves.easeInOut;

  /// 등장·진입
  static const entry = Curves.easeOut;

  /// 감속
  static const decelerate = Curves.easeOutCubic;

  /// 버튼 눌림 복귀 (살짝 튕긴다)
  static const springOut = ElasticOutCurve(0.5);

  // --- stagger ---

  /// 리스트 아이템이 순차 등장하는 간격.
  /// 동시에 팍 뜨지 않게 `index * staggerDelayMs`로 지연을 준다.
  static const staggerDelayMs = 30;

  /// 장면 연출(시작 화면 등)에서 요소 그룹이 순차 등장하는 간격.
  ///
  /// 리스트용 [staggerDelayMs](30ms)와 단위가 다르다 — 그룹 단위 안무는
  /// 한 덩어리씩 "얹히는" 호흡이 필요해 간격이 더 길다.
  static const sceneStagger = Duration(milliseconds: 120);

  /// 아동 화면 최소 전환 시간.
  ///
  /// 발달장애 아동은 급격한 전환의 인지 부하가 크다. 아동 모드 화면에서는
  /// [fast]·[instant]를 쓰지 않고 이 값 이상을 쓴다. (docs/motion.md)
  static const childMinimum = normal;

  /// 리스트 stagger 지연을 계산한다.
  ///
  /// 긴 목록에서 끝까지 지연을 주면 마지막 아이템이 한참 뒤에 뜬다.
  /// 화면에 보이는 앞쪽 [maxStaggered]개까지만 걸고 나머지는 즉시 표시한다.
  static Duration staggerFor(int index, {int maxStaggered = 10}) {
    final capped = index < maxStaggered ? index : maxStaggered;
    return Duration(milliseconds: capped * staggerDelayMs);
  }
}
