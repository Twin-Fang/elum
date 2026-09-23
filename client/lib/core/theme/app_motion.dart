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

  /// 배경 색이 다음 화면 색으로 번지는 시간 (일과 만들기 오로라 · #380).
  ///
  /// **[emphasis](500)를 넘기는 유일한 전환이다.** 500 상한은 "넘으면 기다리게
  /// 된다"는 이유인데, 배경은 아무것도 막지 않는다 — 글자와 버튼은 페이지 전환
  /// ([slow] 400)에 맞춰 이미 자리를 잡고 눌린다. 그 뒤 300ms 동안 색만 뒤따라
  /// 가라앉는다. 400에 맞춰 끝내면 화면 전체가 한 번에 바뀌어 "툭" 바뀐 것으로 읽힌다.
  /// 더 길면(1초 이상) 다음 화면에서 앞 화면 색이 남아 무엇이 바뀌었는지 흐려진다.
  static const ambient = Duration(milliseconds: 700);

  /// 입력이 틀렸을 때 한 번 흔들어 멎기까지의 시간.
  ///
  /// 오류를 색이나 아이콘 대신 움직임으로 알린다 — 이 서비스는 경고색을 쓰지
  /// 않는다. 2.5주기가 이 시간에 들어가므로 한 왕복이 약 175ms다. 더 짧으면
  /// 신경질적으로, 더 길면 늘어지게 보인다.
  static const shake = Duration(milliseconds: 440);

  /// 감쇠 흔들림의 기준 진폭(논리 픽셀).
  ///
  /// 지수 감쇠를 거치므로 실제로 보이는 첫 스윙은 7px대다. 이 값을 그대로
  /// 움직이지 않는다 — 계산식은 [AppShake] 문서 참조.
  static const shakeAmplitude = 10.0;

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
