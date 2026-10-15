import 'package:elum/features/child/data/progress_store.dart';
import 'package:elum/features/child/domain/routine_progress_record.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 아동 카드 진행 상태의 로컬 영속 (이슈 #140).
///
/// 앱을 다시 열어도 체크가 남아야 하고, 서버 반영이 안 끝난 일과는 대기열에 남아야 한다.
/// 저장소가 이걸 잃어버리면 오프라인 퍼스트가 성립하지 않는다.
void main() {
  group('RoutineProgressRecord', () {
    test('JSON으로 왕복해도 완료·보상 집합이 보존된다', () {
      const record = RoutineProgressRecord(
        completed: {'c1', 'c2'},
        rewarded: {'c1'},
      );

      final restored = RoutineProgressRecord.fromJson(record.toJson());

      expect(restored.completed, {'c1', 'c2'});
      expect(restored.rewarded, {'c1'});
    });

    test('빈 JSON에서도 죽지 않는다', () {
      final restored = RoutineProgressRecord.fromJson(const {});

      expect(restored.completed, isEmpty);
      expect(restored.rewarded, isEmpty);
    });
  });

  group('ProgressStore', () {
    late InMemoryStorage storage;
    late ProgressStore store;

    setUp(() {
      storage = InMemoryStorage();
      store = ProgressStore(storage);
    });

    test('clearAll이 진행 기록·대기열·캐시를 함께 지운다', () async {
      // 온보딩 초기화(계정 전환) 후 이전 아이의 체크가 남으면 안 된다.
      await store.save('r1', const RoutineProgressRecord(completed: {'c1'}));
      await store.setPending({'r1'});
      await storage.setCachedTodayRoutinesJson('[]');

      await storage.clearAll();

      expect(store.load('r1'), isNull);
      expect(store.pending, isEmpty);
      expect(storage.cachedTodayRoutinesJson, isNull);
    });
  });
}
