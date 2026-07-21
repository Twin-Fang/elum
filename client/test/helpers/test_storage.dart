import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
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

/// 온보딩 완료 시 서버 연동(PATCH)을 타지 않도록 MemberRepository를 no-op으로 교체한다.
///
/// 실제 [memberRepositoryProvider]는 dio로 네트워크를 호출해, 위젯 테스트에서
/// pending timer를 남겨 `!timersPending` 어서션을 깨뜨린다. 온보딩 화면 테스트는
/// 서버 저장을 검증 대상으로 삼지 않으므로 호출을 삼키는 fake로 바꿔 끼운다.
// ignore: strict_top_level_inference
testMemberRepoOverride() {
  return memberRepositoryProvider.overrideWithValue(_NoopMemberRepository());
}

/// 모든 저장 호출을 삼키는 MemberRepository. 네트워크를 타지 않는다.
class _NoopMemberRepository extends MemberRepository {
  _NoopMemberRepository() : super(dio: Dio());

  @override
  Future<void> updateNickname(String nickname) async {}

  @override
  Future<void> updateSupportGoals(List<String> goals) async {}

  @override
  Future<void> updateCharacter(String character) async {}
}
