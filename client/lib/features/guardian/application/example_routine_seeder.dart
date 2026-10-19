import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/storage/local_storage.dart';
import 'routine_providers.dart';

/// 예시 생성 결과: 대기 없음 · 만듦 · 실패(다음에 재시도) · 실패(포기)
enum ExampleSeedOutcome {
  nothingPending,
  created,
  failedWillRetry,
  failedGaveUp;

  /// 보호자에게 실패를 알릴 결과인가
  bool get isFailure => this == failedWillRetry || this == failedGaveUp;
}

final exampleRoutineSeederProvider = Provider<ExampleRoutineSeeder>(
  ExampleRoutineSeeder.new,
);

/// 온보딩 예시 일과 생성 (#803): 대기 분류 확인 > 서버 요청 > 성공·포기 시 대기값 비움 > 오늘 목록 갱신
///
/// 온보딩이 고른 분류를 저장소에 남기고, 보호자 홈이 들어올 때마다 이것을 부른다.
/// 실패해도 홈은 그대로 — 결과만 돌려주고 안내는 화면이 한다.
class ExampleRoutineSeeder {
  ExampleRoutineSeeder(this._ref);

  final Ref _ref;

  /// 실패 허용 횟수 — 첫 실패는 다음 홈 진입 때 다시, 두 번째면 포기
  static const maxAttempts = 2;

  /// 400 — 앱·서버 분류 코드 불일치. 다시 해도 같다
  static const _badRequestStatus = 400;

  /// 같은 세션에서 겹쳐 부르면(홈이 둘 겹침) 한 번만 보낸다
  bool _isRunning = false;

  Future<ExampleSeedOutcome> seedPending() async {
    final storage = _ref.read(localStorageProvider);
    final pending = storage.pendingExampleCategories;
    if (pending.isEmpty || _isRunning) return ExampleSeedOutcome.nothingPending;

    _isRunning = true;
    try {
      final attempt = await _ref
          .read(routineExampleRepositoryProvider)
          .createExamples(pending);
      final failure = attempt.failure;

      // 성공 (이미 만들어 빈 목록이어도 성공)
      if (failure == null) {
        await _clearPending(storage);
        _ref.invalidate(todayRoutinesProvider);
        return ExampleSeedOutcome.created;
      }

      // 재시도해도 같은 실패 (400) 또는 허용 횟수 초과 > 포기
      final attempts = storage.exampleSeedAttempts + 1;
      if (failure.server?.statusCode == _badRequestStatus ||
          attempts >= maxAttempts) {
        AppLogger.error('[routine example] gave up', failure, null, {
          'attempts': attempts,
        });
        await _clearPending(storage);
        return ExampleSeedOutcome.failedGaveUp;
      }

      await storage.setExampleSeedAttempts(attempts);
      return ExampleSeedOutcome.failedWillRetry;
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _clearPending(LocalStorage storage) async {
    await storage.setPendingExampleCategories(const []);
    await storage.setExampleSeedAttempts(0);
  }
}
