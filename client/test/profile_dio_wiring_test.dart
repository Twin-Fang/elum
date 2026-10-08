import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/profile/application/profile_session.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 앱이 실제로 쓰는 Dio(`dioProvider`)에 이룸이 헤더가 붙어 있는가 (#362).
///
/// 인터셉터 단위 테스트가 통과해도 **provider 에 안 달려 있으면** 헤더는 영영 안 나간다.
/// 조용히 첫 이룸이만 보게 되므로 실제 체인으로 확인한다.
void main() {
  late InMemoryStorage storage;
  late FakeAdapter adapter;
  var serverProfiles = const [ProfileSummary(id: 'p-a'), ProfileSummary(id: 'p-b')];

  ProviderContainer build(Map<String, Object?> routes) {
    final container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        memberProvider.overrideWith((ref) async => Member(profiles: serverProfiles, profilesKnown: true)),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
      ],
    );
    addTearDown(container.dispose);
    adapter = FakeAdapter(routes);
    container.read(dioProvider).httpClientAdapter = adapter;
    return container;
  }

  setUp(() {
    storage = InMemoryStorage(onboardingCompleted: true);
    serverProfiles = const [ProfileSummary(id: 'p-a'), ProfileSummary(id: 'p-b')];
  });

  test('고른 이룸이가 실제 Dio 요청에 X-Profile-Id 로 실린다', () async {
    await storage.setSelectedProfileId('p-b');
    final c = build({'GET /api/routines/today': <Object>[]});

    await c.read(dioProvider).get<dynamic>('/api/routines/today');

    expect(adapter.sentHeaders['GET /api/routines/today']!['X-Profile-Id'], 'p-b');
  });

  test('이룸이 휴대폰은 헤더를 싣지 않는다 — 서버가 연결된 이룸이만 보여 준다', () async {
    await storage.setSelectedProfileId('p-b');
    await storage.setElumiDevice(true);
    final c = build({'GET /api/routines/today': <Object>[]});

    await c.read(dioProvider).get<dynamic>('/api/routines/today');

    expect(
      adapter.sentHeaders['GET /api/routines/today']!.containsKey('X-Profile-Id'),
      isFalse,
    );
  });

  test('고른 이룸이를 볼 수 없다는 응답을 받으면 선택을 풀고 첫 이룸이로 돌아온다', () async {
    await storage.setSelectedProfileId('p-gone');
    final c = build({
      'GET /api/routines/today': const FakeHttpError(
        403,
        errorCode: 'PROFILE_ACCESS_DENIED',
        errorMessage: '이 이룸이의 정보를 볼 수 없어요.',
      ),
    });
    c.listen(profileSessionProvider, (_, _) {});
    await c.read(memberProvider.future);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      c.read(dioProvider).get<dynamic>('/api/routines/today'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await c.read(memberProvider.future);
    await Future<void>.delayed(Duration.zero);

    // 서버가 준 목록(p-a, p-b)의 첫 이룸이로 맞춰졌다
    expect(c.read(profileSessionProvider).selectedId, 'p-a');
    expect(storage.selectedProfileId, 'p-a');
  });

  test('연결된 이룸이가 없다는 응답은 이룸이 없음으로 표시한다 (E29)', () async {
    serverProfiles = const [];
    final c = build({
      'GET /api/routines/today': const FakeHttpError(
        404,
        errorCode: 'PROFILE_NOT_FOUND',
        errorMessage: '등록된 이룸이가 없어요.',
      ),
    });
    c.listen(profileSessionProvider, (_, _) {});

    await expectLater(
      c.read(dioProvider).get<dynamic>('/api/routines/today'),
      throwsA(isA<DioException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(profileSessionProvider).noProfile, isTrue);
  });
}
