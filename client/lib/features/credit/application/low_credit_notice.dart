import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';
import '../../member/application/plan_access.dart';
import '../data/credit_repository.dart';
import '../domain/credit_summary.dart';
import 'ad_reward_flow.dart';

/// 일과 1개 어림 크레딧 (글 1 + 카드 그림 7장): 남은 양이 이보다 적으면 홈에서 미리 알림
const lowCreditRoutineEstimate = 8;

/// 홈 크레딧 부족 카드에 그릴 것: 남은 양 (0 이면 `다 썼어요` 제목) + 닫기에 쓸 주기 표지
typedef LowCreditNotice = ({int available, String period});

/// 크레딧 부족 카드를 닫은 주기 표지 (그 주기의 다음 초기화 시각). 다음 주기가 되면 표지가 달라 다시 보임
class LowCreditNoticeDismissal extends Notifier<String?> {
  @override
  String? build() => ref.read(localStorageProvider).lowCreditNoticeDismissedPeriod;

  /// 닫기(x): 이번 주기 표지를 저장하고 숨김
  Future<void> dismiss(String period) async {
    state = period;
    await ref.read(localStorageProvider).setLowCreditNoticeDismissedPeriod(period);
  }
}

final lowCreditNoticeDismissalProvider =
    NotifierProvider<LowCreditNoticeDismissal, String?>(LowCreditNoticeDismissal.new);

/// 홈 크레딧 부족 카드 (보이면 값, 아니면 null)
///
/// 조건 4개: Free · 크레딧 켜짐이고 남은 양 < [lowCreditRoutineEstimate] · 광고를 미리 불러 둠 · 이번 주기에 닫지 않음.
/// 잔액·광고 조회가 끝나지 않았거나 실패하면 안 보임 (안내일 뿐이라 실패를 띄우지 않음). 앞 조건이 맞을 때만 광고를 불러옴
final lowCreditNoticeProvider = Provider.autoDispose<LowCreditNotice?>((ref) {
  if (ref.watch(planAccessProvider).isPro) return null;
  final summary = ref.watch(creditSummaryProvider).value;
  if (summary == null || !summary.enabled || summary.available >= lowCreditRoutineEstimate) return null;
  final period = creditPeriodKeyOf(summary);
  if (ref.watch(lowCreditNoticeDismissalProvider) == period) return null;
  if (!ref.watch(adRewardOfferStateProvider).isReady) return null;
  return (available: summary.available, period: period);
});

/// 크레딧 주기 표지: 다음 초기화 시각 (모르면 주기 시작 · 둘 다 없으면 빈 값)
String creditPeriodKeyOf(CreditSummary summary) =>
    (summary.nextResetAt ?? summary.periodStart)?.toIso8601String() ?? '';
