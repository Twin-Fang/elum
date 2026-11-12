import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger/app_logger.dart';
import '../core/storage/local_storage.dart';
import '../features/credit/application/low_credit_notice.dart';
import '../features/guardian/domain/home_suggestion.dart';
import '../features/member/application/plan_access.dart';
import '../features/notification/application/device_notification_permission_controller.dart';
import '../features/notification/application/home_notification_notice_provider.dart';
import 'home_auto_send_upsell.dart';
import 'home_notice_day.dart';
import 'home_suggestion_provider.dart';

/// 보호자 홈 안내 카드 종류 4개: 선언 순서가 우선순위 (알림 꺼짐 > 크레딧 부족 > 권유 > 자동 보내기 안내)
enum HomeNoticeKind { notificationOff, lowCredit, suggestion, autoSendUpsell }

/// 홈에 보일 안내 카드 하나: 종류 + 권유 카드인가 (하루 1개 기록 대상)
typedef HomeNoticeChoice = ({HomeNoticeKind kind, bool isUpsell});

/// 오늘 저절로 보인 권유 카드: 날짜 `yyyy-MM-dd` + 종류 이름
typedef HomeUpsellShownRecord = ({String day, String kindName});

/// 기록 글 `{yyyy-MM-dd}|{종류 이름}` 구분자
const _upsellRecordDelimiter = '|';

final homeUpsellShownRecordProvider = NotifierProvider<HomeUpsellShownRecordNotifier, HomeUpsellShownRecord?>(
  HomeUpsellShownRecordNotifier.new,
);

/// 권유 카드 하루 1개 기록 (docs/08 §5-10 원칙 2): 그날 처음 보인 권유 종류만 그날 다시 보임
class HomeUpsellShownRecordNotifier extends Notifier<HomeUpsellShownRecord?> {
  @override
  HomeUpsellShownRecord? build() {
    final raw = ref.read(localStorageProvider).homeUpsellShownRecord;
    final parts = raw?.split(_upsellRecordDelimiter);
    if (parts == null || parts.length != 2) return null;
    return (day: parts[0], kindName: parts[1]);
  }

  /// 권유 카드가 홈에 보임: 오늘 기록이 없을 때만 저장 (같은 날 두 번째 종류는 [homeNoticeChoiceProvider] 가 이미 거름)
  Future<void> markShown(HomeNoticeKind kind, DateTime now) async {
    final today = homeNoticeDayKeyOf(now);
    if (state?.day == today) return;
    state = (day: today, kindName: kind.name);
    try {
      await ref.read(localStorageProvider).setHomeUpsellShownRecord('$today$_upsellRecordDelimiter${kind.name}');
    } catch (e, stack) {
      // 안내용 기록이라 저장 실패로 화면 동작을 막지 않음 (이번 실행에서는 기록 유지)
      AppLogger.error('homeNotice', e, stack, {'step': 'saveUpsellRecord'});
    }
  }
}

/// 지금 홈에 보일 안내 카드 하나 (없으면 null) — 홈 안내 카드 우선순위의 단일 원본
///
/// 우선순위 순으로 처음 보일 수 있는 하나만. 권유 카드(크레딧 부족 · 자동 보내기 안내 · Pro 로 가는 자동 보내기 제안)는
/// 하루 1종류까지: 오늘 다른 권유가 이미 보였으면 건너뜀
final homeNoticeChoiceProvider = Provider.autoDispose<HomeNoticeChoice?>((ref) {
  final todayUpsell = ref.watch(homeUpsellShownRecordProvider);
  final today = homeNoticeDayKeyOf(DateTime.now());
  bool isUpsellAllowedToday(HomeNoticeKind kind) =>
      todayUpsell == null || todayUpsell.day != today || todayUpsell.kindName == kind.name;

  for (final kind in HomeNoticeKind.values) {
    // 앞 종류가 보이면 뒤 종류의 데이터는 읽지 않음 (필요할 때만 조회)
    if (!_isNoticeVisible(ref, kind)) continue;
    final isUpsell = _isNoticeUpsell(ref, kind);
    if (isUpsell && !isUpsellAllowedToday(kind)) continue;
    return (kind: kind, isUpsell: isUpsell);
  }
  return null;
});

/// 종류별 보일 조건 (닫기 기록 포함)
bool _isNoticeVisible(Ref ref, HomeNoticeKind kind) => switch (kind) {
  HomeNoticeKind.notificationOff =>
    ref.watch(deviceNotificationPermissionControllerProvider) && !ref.watch(homeNotificationNoticeDismissalProvider),
  HomeNoticeKind.lowCredit => ref.watch(lowCreditNoticeProvider) != null,
  HomeNoticeKind.suggestion => ref.watch(homeSuggestionProvider) != null,
  HomeNoticeKind.autoSendUpsell => ref.watch(homeAutoSendUpsellProvider),
};

/// 권유 카드인가: 크레딧 부족(광고 보상) · 자동 보내기 안내(Pro) · 반복을 못 쓰는 계정의 자동 보내기 제안(요금제 화면)
bool _isNoticeUpsell(Ref ref, HomeNoticeKind kind) => switch (kind) {
  HomeNoticeKind.notificationOff => false,
  HomeNoticeKind.lowCredit || HomeNoticeKind.autoSendUpsell => true,
  HomeNoticeKind.suggestion =>
    ref.watch(homeSuggestionProvider)?.kind == HomeSuggestionKind.autoSend &&
        !ref.watch(planAccessProvider).canScheduleRoutines,
};
