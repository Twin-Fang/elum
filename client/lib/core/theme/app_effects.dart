/// 효과 토큰 — 흐림 세기의 단일 출처. 화면에서 `ImageFilter.blur(sigmaX: 6)` 같은 숫자를 직접 쓰지 않는다
abstract final class AppEffects {
  /// Pro 미리 보기 견본 화면 흐림 (글자는 못 읽고 화면 모양만 보이는 세기)
  static const proTeaserBlurSigma = 6.0;
}
