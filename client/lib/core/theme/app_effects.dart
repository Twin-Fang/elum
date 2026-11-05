/// 효과 토큰 — 흐림 세기의 단일 출처. 화면에서 `ImageFilter.blur(sigmaX: 6)` 같은 숫자를 직접 쓰지 않는다
abstract final class AppEffects {
  /// Pro 미리 보기 견본 화면 흐림 (글자는 못 읽고 화면 모양만 보이는 세기)
  static const proTeaserBlurSigma = 6.0;

  /// 꺼진 기능의 목록 흐림 (내용은 읽히고 눌러 고칠 수 있지만 지금 쓰이지 않는다는 표시)
  static const inactiveContentOpacity = 0.45;
}
