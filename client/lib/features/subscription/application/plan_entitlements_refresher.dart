import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../credit/application/credit_summary_refresh.dart';
import '../../guardian/application/routine_memory_controller.dart';
import '../../guardian/application/routine_schedule_controller.dart';
import '../../guardian/application/weekly_report_providers.dart';
import '../../member/application/member_providers.dart';
import '../../member/domain/plan_entitlements.dart';

/// 서버 권한 묶음이 바뀌면(Pro 시작·회수·만료) 서버가 권한으로 내용을 정하는 값을 다시 받는다 (#1135)
///
/// 권한 변화는 회원 정보 갱신(주기·앱 복귀)이 알아챈다. 보호자 화면 틀(`GuardianShell`)이 떠 있는 동안만 산다.
/// 개발자 도구 요금제 흉내는 대상 아님 — 서버 값이 그대로라 다시 받아도 같다
final planEntitlementsRefresherProvider = Provider.autoDispose<void>((ref) {
  // 마지막으로 안 권한 (회원 조회 중·실패로 잠깐 null 이 돼도 이 값과 비교)
  PlanEntitlements? lastKnownEntitlements;
  ref.listen<PlanEntitlements?>(
    memberProvider.select((member) => member.value?.entitlements),
    (_, nextEntitlements) {
      if (nextEntitlements == null) return;
      final previousEntitlements = lastKnownEntitlements;
      lastKnownEntitlements = nextEntitlements;
      // 처음 안 값 · 그대로면 받지 않음 (앱 시작 때 두 번 받지 않게)
      if (previousEntitlements == null ||
          previousEntitlements == nextEntitlements) {
        return;
      }
      _refreshEntitlementDependents(ref);
    },
    fireImmediately: true,
  );
});

/// 권한에 따라 서버 응답이 달라지는 값 4개: 주간 계획(멈춤 표시) · 주간 리포트 · AI 메모 · 크레딧 요약(오늘 남은 무료 다시 그리기)
///
/// 보는 화면이 없는 값(autoDispose)은 버려져 있어 아무 일도 없다. 새 Pro 기능이 서버 값을 캐시하면 여기에 한 줄
void _refreshEntitlementDependents(Ref ref) {
  ref.invalidate(routineSchedulePlanProvider);
  ref.invalidate(weeklyReportProvider);
  ref.invalidate(routineMemoryControllerProvider);
  refreshCreditSummary(ref);
}
