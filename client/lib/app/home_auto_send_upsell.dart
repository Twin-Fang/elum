import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger/app_logger.dart';
import '../core/storage/local_storage.dart';
import '../features/guardian/application/routine_providers.dart';
import '../features/member/application/plan_access.dart';
import '../features/subscription/domain/plan_benefit.dart';
import 'home_notice_day.dart';

/// 자동 보내기 안내 카드를 보일 일과관리 일과 수 (예시 일과 제외, 이상이면 보임)
const homeAutoSendUpsellRoutineCount = 3;

/// 자동 보내기 안내 카드 기록: 처음 보인 날 `yyyy-MM-dd` (없으면 null) + 닫거나 누름
typedef HomeAutoSendUpsellRecord = ({String? firstShownDay, bool isClosed});

final homeAutoSendUpsellRecordProvider =
    NotifierProvider<HomeAutoSendUpsellRecordNotifier, HomeAutoSendUpsellRecord>(
  HomeAutoSendUpsellRecordNotifier.new,
);

/// 자동 보내기 안내 카드 기록 (#1284): 처음 보인 날 저장 (그날만 보임) · 닫기·누름 저장 (다시 안 보임)
class HomeAutoSendUpsellRecordNotifier extends Notifier<HomeAutoSendUpsellRecord> {
  @override
  HomeAutoSendUpsellRecord build() {
    final storage = ref.read(localStorageProvider);
    return (firstShownDay: storage.homeAutoSendUpsellFirstShownDay, isClosed: storage.isHomeAutoSendUpsellClosed);
  }

  /// 홈에 보임: 처음이면 오늘 날짜 저장 (이미 있으면 그대로)
  Future<void> markShown(DateTime now) async {
    if (state.firstShownDay != null) return;
    final today = homeNoticeDayKeyOf(now);
    state = (firstShownDay: today, isClosed: state.isClosed);
    await _save('saveFirstShownDay', (storage) => storage.setHomeAutoSendUpsellFirstShownDay(today));
  }

  /// 닫기(x) · 버튼 누름: 다시 안 보임
  Future<void> close() async {
    state = (firstShownDay: state.firstShownDay, isClosed: true);
    await _save('saveClosed', (storage) => storage.setHomeAutoSendUpsellClosed(true));
  }

  // 안내용 기록이라 저장 실패로 화면 동작을 막지 않음 (이번 실행에서는 상태 유지)
  Future<void> _save(String step, Future<void> Function(LocalStorage storage) write) async {
    try {
      await write(ref.read(localStorageProvider));
    } catch (e, stack) {
      AppLogger.error('homeAutoSendUpsell', e, stack, {'step': step});
    }
  }
}

/// 홈 자동 보내기 안내 카드를 보일 때인가 (#1284)
///
/// 조건 4개: 닫지 않음 · 처음 보인 날이 없거나 오늘 · 반복 일과로 Pro 를 권할 계정(Free · 판매 중) · 예시 뺀 일과관리 일과 3개 이상.
/// 일과관리 목록을 못 받았으면 안 보임 (안내일 뿐이라 실패를 띄우지 않음)
final homeAutoSendUpsellProvider = Provider.autoDispose<bool>((ref) {
  final record = ref.watch(homeAutoSendUpsellRecordProvider);
  if (record.isClosed) return false;
  final firstShownDay = record.firstShownDay;
  if (firstShownDay != null && firstShownDay != homeNoticeDayKeyOf(DateTime.now())) return false;
  if (!ref.watch(planAccessProvider).shouldShowTeaserFor(PlanBenefit.routineSchedule)) return false;
  final libraryRoutines = ref.watch(routineLibraryProvider).value;
  if (libraryRoutines == null) return false;
  final createdRoutineCount = libraryRoutines.where((routine) => !routine.isExample).length;
  return createdRoutineCount >= homeAutoSendUpsellRoutineCount;
});
