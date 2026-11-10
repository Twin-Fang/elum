import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_storage.dart';

/// 홈 `알림이 꺼져 있어요` 띠를 닫으면 숨기는 기간
const homeNotificationNoticeHiddenDays = 7;

/// 보호자 홈 띠를 닫은 상태: 닫은 뒤 7일 동안만 숨김 (알림 화면 · 설정 안내는 이것과 무관하게 계속 보임)
class HomeNotificationNoticeDismissal extends Notifier<bool> {
  @override
  bool build() {
    final dismissedAt = ref.read(localStorageProvider).homeNotificationNoticeDismissedAt;
    if (dismissedAt == null) return false;
    return DateTime.now().difference(dismissedAt) < const Duration(days: homeNotificationNoticeHiddenDays);
  }

  /// 닫기(x): 지금 시각을 저장하고 숨김
  Future<void> dismiss() async {
    state = true;
    await ref.read(localStorageProvider).setHomeNotificationNoticeDismissedAt(DateTime.now());
  }
}

final homeNotificationNoticeDismissalProvider =
    NotifierProvider<HomeNotificationNoticeDismissal, bool>(HomeNotificationNoticeDismissal.new);
