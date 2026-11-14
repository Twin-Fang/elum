import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../logger/app_logger.dart';

/// OS 기본 별점 창 호출 (iOS SKStoreReviewController · Android Play In-App Review, #1352)
/// 실제 표시 여부·횟수는 OS 가 정함 > 앱은 호출만, 실패해도 화면 흐름 유지
class StoreReviewClient {
  const StoreReviewClient();

  /// 별점 창 요청: 지원 안 함·오류면 false (예외는 로그만)
  Future<bool> requestReview() async {
    try {
      final inAppReview = InAppReview.instance;
      if (!await inAppReview.isAvailable()) {
        AppLogger.info('[store review] skipped : not available');
        return false;
      }
      await inAppReview.requestReview();
      AppLogger.info('[store review] requested');
      return true;
    } catch (error) {
      AppLogger.info('[store review] failed : $error');
      return false;
    }
  }
}

final storeReviewClientProvider = Provider<StoreReviewClient>(
  (ref) => const StoreReviewClient(),
);
