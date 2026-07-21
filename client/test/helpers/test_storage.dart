import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';

/// ProviderScope에 넣을 저장소 override를 만든다.
///
/// 실제 SharedPreferences는 플랫폼 채널을 타므로 위젯 테스트에서 쓸 수 없다.
/// 메모리 구현으로 바꿔 끼운다.
///
/// [pin]을 주면 그 값이 저장된 상태로 시작한다 — 모드 전환 PIN 검증 테스트용.
/// 주지 않으면 PIN 미설정(온보딩을 건너뛴 개발 상태)이 된다.
///
/// riverpod 3.x가 `Override` 타입을 export하지 않아 반환 타입은 추론에 맡긴다.
// ignore: strict_top_level_inference
testStorageOverride({bool onboardingCompleted = false, String? pin}) {
  return localStorageProvider.overrideWithValue(
    InMemoryStorage(onboardingCompleted: onboardingCompleted, pin: pin),
  );
}
