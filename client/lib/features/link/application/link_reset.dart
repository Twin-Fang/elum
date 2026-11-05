import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:go_router/go_router.dart';

import '../../child/application/child_routine_notifier.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/device_link_repository.dart';
import '../../../core/storage/local_storage.dart';
import '../../member/application/member_providers.dart';
import '../../guardian/application/routine_providers.dart';
import '../../profile/application/profile_session.dart';
import '../../../core/router/routes.dart';

/// 연결이 끊긴 이룸이 휴대폰의 **메모리**를 비운다.
///
/// 저장소(SharedPreferences)는 [DeviceLinkRepository.releaseThisPhone] 이 이미 비웠다. 그런데 provider 는
/// 앱이 켜질 때 읽어 둔 값·받아 둔 목록을 메모리에 들고 있어, 비우지 않으면 **다른 이룸이에게 새로 연결해도**
/// 이전 이룸이의 이름·일과·체크 기록이 화면에 남는다 (로그인에서 이전 계정 이름이 남는 것과 같은 문제).
extension LinkedProfileReset on ProviderContainer {
  void forgetLinkedProfile() {
    _forgetLinkedProfileMemory(read(memberPrefetchProvider), invalidate);
    invalidate(childRoutineProvider);
  }
}

/// 연결 성공 직후 연결 전 계정의 **메모리**를 버린다 (#1148).
///
/// 연결은 토큰을 이룸이 세션으로 바꾸는 계정 전환인데, 이름(onboarding·회원 정보)·고른 이룸이·일과는
/// 연결 전 계정 값을 들고 있어 홈 인사말이 기본 호칭으로 남았다. 저장소는 연결이 이미 새 값으로 채웠다.
/// 체크 대기열(`childRoutineProvider`)은 비우지 않음 — 아직 못 보낸 체크가 있을 수 있음.
extension LinkedSessionStart on Ref {
  void forgetPreLinkAccount() =>
      _forgetLinkedProfileMemory(read(memberPrefetchProvider), invalidate);
}

/// 연결 전후 이룸이 이름·고른 이룸이·일과 메모리 비우기 (연결·연결 해제 공통)
void _forgetLinkedProfileMemory(
  MemberPrefetch memberPrefetch,
  void Function(ProviderOrFamily provider) invalidate,
) {
  // 주기 갱신이 받아 둔 이전 회원 정보 (남기면 다시 만들어진 회원 정보가 이것을 꺼내 씀)
  memberPrefetch.discard();
  invalidate(onboardingProvider);
  invalidate(memberProvider);
  invalidate(profileSessionProvider);
  invalidate(todayRoutinesProvider);
  invalidate(pastRoutinesProvider);
  invalidate(myRoutinesProvider);
  invalidate(routineFlowProvider);
}

/// 이룸이 휴대폰의 **세션이 끝났을 때**(토큰 갱신까지 실패) 하는 일.
///
/// 서버가 이 연결을 더는 인정하지 않는다 — 보호자가 끊었거나(리프레시 토큰 폐기) 연결이 지워졌다. 이 휴대폰은
/// 스스로 연결 해제 상태가 된다.
///
/// 1. 로컬을 비운다 — 토큰·이룸이 정보·일과 캐시·체크 기록. `이룸이 휴대폰` 표식은 로그인할 때 내려간다.
///    카드 그림 캐시는 세션 종료 때 이미 비워졌다(`dioProvider`).
/// 2. 로그인으로 보낸다. 메모리는 이동 뒤에 비운다 — 이동 전에 비우면 아직 보이는 이룸이 홈이 빈 값으로
///    다시 그려진다.
Future<void> endElumiLinkAfterSessionLoss({
  required DeviceLinkRepository repo,
  required GoRouter router,
  required ProviderContainer container,
}) async {
  await repo.releaseThisPhone(lost: true);
  // 토큰을 방금 지웠다 — 이룸이 휴대폰도 로그인부터 다시 한다
  router.go(Routes.login);
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
