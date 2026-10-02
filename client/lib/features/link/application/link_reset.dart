import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../child/application/child_routine_notifier.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../guardian/data/routine_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/device_link_repository.dart';

/// 연결이 끊긴 이룸이 휴대폰의 **메모리**를 비운다 (#363).
///
/// 저장소(SharedPreferences)는 [DeviceLinkRepository.releaseThisPhone] 이 이미 비웠다. 그런데 provider 는
/// 앱이 켜질 때 읽어 둔 값·받아 둔 목록을 메모리에 들고 있어, 비우지 않으면 **다른 이룸이에게 새로 연결해도**
/// 이전 이룸이의 이름·일과·체크 기록이 화면에 남는다 (로그인에서 이전 계정 이름이 남던 #177 과 같은 문제).
extension LinkedProfileReset on ProviderContainer {
  void forgetLinkedProfile() {
    invalidate(onboardingProvider);
    invalidate(memberProvider);
    invalidate(todayRoutinesProvider);
    invalidate(pastRoutinesProvider);
    invalidate(myRoutinesProvider);
    invalidate(routineFlowProvider);
    invalidate(childRoutineProvider);
  }
}

/// 이룸이 휴대폰의 **세션이 끝났을 때**(토큰 갱신까지 실패) 하는 일 (#363 · #359).
///
/// 서버가 이 연결을 더는 인정하지 않는다 — 보호자가 끊었거나(리프레시 토큰 폐기) 연결이 지워졌다. 이 휴대폰은
/// 스스로 연결 해제 상태가 된다.
///
/// 1. 로컬을 비운다 — 토큰·이룸이 정보·일과 캐시·체크 기록. **`이룸이 휴대폰` 표식은 남긴다**(로그인 화면이
///    아니라 연결 화면으로 가야 한다, #206). 카드 그림 캐시는 세션 종료 때 이미 비워졌다(`dioProvider`).
/// 2. `연결이 끊어졌어요` 표식을 세운다 — 앱을 껐다 켜도 연결 화면이 그 말을 한다.
/// 3. 연결 암호 넣기로 보낸다. 메모리는 이동 뒤에 비운다 — 이동 전에 비우면 아직 보이는 이룸이 홈이 빈 값으로
///    다시 그려진다.
Future<void> endElumiLinkAfterSessionLoss({
  required DeviceLinkRepository repo,
  required GoRouter router,
  required ProviderContainer container,
}) async {
  await repo.releaseThisPhone(lost: true);
  // 토큰을 방금 지웠다 — 뒤로가기는 로그인 화면으로 간다 (#542)
  goToLinkEnter(router, hasSession: false);
  container.forgetLinkedProfile();
}

/// 세션이 끝났을 때(토큰 갱신 실패) 갈 곳. 보호자 휴대폰은 로그인, 이룸이 휴대폰은 연결이 끊긴 것이라
/// [endElumiLinkAfterSessionLoss].
Future<void> handleSessionExpired({
  required GoRouter router,
  required ProviderContainer container,
}) async {
  if (!container.read(localStorageProvider).isElumiDevice) {
    router.go(Routes.login);
    return;
  }
  await endElumiLinkAfterSessionLoss(
    repo: container.read(deviceLinkRepositoryProvider),
    router: router,
    container: container,
  );
}
