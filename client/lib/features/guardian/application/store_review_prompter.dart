import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/review/store_review_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../child/application/child_routine_notifier.dart';
import 'home_routines.dart';

/// 보호자 홈 별점 요청: 끝난 일과를 본 날짜 기록 > 2일 이상이면 OS 별점 창 1회 (#1352)
/// 조건 3개: 별점 창 아직 안 띄움, 홈 코치마크 본 뒤, 오늘 끝난 일과 1개 이상
class StoreReviewPrompter {
  StoreReviewPrompter(this._ref);

  final Ref _ref;

  /// 끝난 일과를 본 날이 이만큼 쌓이면 요청 (하루만으로는 앱을 써 본 게 아님)
  static const requiredCompletedDayCount = 2;

  /// 기록 보관 개수 (요청 판단에 필요한 만큼만)
  static const maximumStoredDayCount = 10;

  /// 오늘 일과 > 끝난 날 기록 > 조건 충족 시 별점 창 요청 (요청했으면 true)
  Future<bool> recordAndMaybeRequest({required DateTime now}) async {
    final storage = _ref.read(localStorageProvider);
    if (storage.hasRequestedStoreReview || !storage.isHomeCoachSeen) {
      return false;
    }
    if (!_hasCompletedRoutineToday()) return false;

    // 오늘 날짜 기록 (중복 없이, 최근 것만)
    final today = _toDayKey(now);
    final completedDays = storage.storeReviewCompletedDays;
    if (!completedDays.contains(today)) {
      final updatedDays = [...completedDays, today];
      await storage.setStoreReviewCompletedDays(
        updatedDays.length > maximumStoredDayCount
            ? updatedDays.sublist(updatedDays.length - maximumStoredDayCount)
            : updatedDays,
      );
    }
    if (storage.storeReviewCompletedDays.length < requiredCompletedDayCount) {
      return false;
    }

    // 먼저 기록 > 요청 (실패·창 안 뜸이어도 다시 묻지 않음)
    await storage.setHasRequestedStoreReview(true);
    return _ref.read(storeReviewClientProvider).requestReview();
  }

  bool _hasCompletedRoutineToday() {
    final progress = _ref.read(childRoutineProvider);
    return _ref
        .read(homeRoutinesProvider)
        .any((routine) => routineProgress(routine, progress) >= 1);
  }

  /// 날짜 > 기록 키 (yyyy-MM-dd, 기기 시간대)
  static String _toDayKey(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';
}

final storeReviewPrompterProvider = Provider<StoreReviewPrompter>(
  StoreReviewPrompter.new,
);
