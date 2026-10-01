import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guardian/application/routine_notifier.dart';
import '../../guardian/data/routine_repository.dart';

/// 다른 계정으로 로그인했을 때 **이전 계정의 일과를 메모리에서 버린다** (#482).
///
/// 일과 목록 provider 는 계정과 무관해서 한 번 받으면 앱이 꺼질 때까지 값을 들고 있다.
/// 로그아웃·탈퇴는 저장소만 비우고 로그인 화면으로 가므로(회원 정보가 되살아나는 것을 막으려고
/// 메모리는 비우지 않는다 — #362), 앱을 끄지 않고 다른 계정으로 들어오면 홈이 이전 계정의
/// 오늘·지난 일과와 임시저장을 그대로 그렸다.
///
/// 로그아웃·탈퇴·세션 만료가 모두 로그인 화면을 거치므로 **로그인 성공 한 곳**에서 부른다.
/// 이룸이 화면의 체크 대기열(`childRoutineProvider`)은 건드리지 않는다 — 아직 서버에 못 보낸 체크가
/// 있을 수 있고(`ProfileSessionNotifier._refreshScoped` 와 같은 규칙), 보호자 로그아웃·탈퇴의
/// 저장소 정리가 이미 대기열 키를 지운다.
///
/// 새 계정 단위의 메모리 상태(provider)가 생기면 여기에 더한다. 한 곳만 빠져도 이전 계정의 것이 남는다.
extension AccountScopedReset on WidgetRef {
  void forgetPreviousAccountRoutines() {
    // 오늘 · 지난 · 전체 — 한쪽만 비우면 화면마다 다른 것을 본다 (#353)
    refreshRoutines();
    invalidate(routineSuggestionsProvider);
    // 만들던 일과 입력·질문·카드. 이전 계정의 원문이 새 계정 화면에 남지 않게 한다.
    invalidate(routineFlowProvider);
  }
}
