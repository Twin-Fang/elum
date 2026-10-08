import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 이룸이 휴대폰 연결 끊기의 저장소 쪽 (#363 · 명세 §8-5).
///
/// - 보호자가 끊는다([DeviceLinkRepository.revoke]) — 이미 끊겨 있으면 실패가 아니다.
/// - 이룸이 휴대폰이 스스로 끊는다([DeviceLinkRepository.disconnectThisPhone]) — **서버가 끊긴 뒤에만** 로컬을 비운다.
void main() {
  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;

  ({DeviceLinkRepository repo, FakeAdapter adapter}) build(
    Map<String, Object?> routes,
  ) {
    final adapter = FakeAdapter(routes);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    return (
      repo: DeviceLinkRepository(dio: dio, tokens: tokens, storage: storage),
      adapter: adapter,
    );
  }

  setUp(() async {
    storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setNickname('하늘이');
    await storage.setCharacter('FOX');
    await storage.setCachedTodayRoutinesJson('[{"id":"r1"}]');
    await storage.setRoutineProgressJson('r1', '{"done":true}');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
  });

  group('보호자가 끊는다 — revoke', () {
    test('끊으면 done, 연결 ID 로 DELETE 를 보낸다', () async {
      final t = build({
        'DELETE /api/device-links/l1': const <String, Object?>{},
      });

      final result = await t.repo.revoke('l1');

      expect(result.outcome, RevokeOutcome.done);
      expect(result.isGone, isTrue);
      expect(t.adapter.calls, ['DELETE /api/device-links/l1']);
    });

    test(
      '이미 끊겨 있으면(404 DEVICE_LINK_NOT_CONNECTED) 실패가 아니라 alreadyGone 이다',
      () async {
        final t = build({
          'DELETE /api/device-links/l1': const FakeHttpError(
            404,
            errorCode: 'DEVICE_LINK_NOT_CONNECTED',
            errorMessage: '연결된 이룸이 휴대폰이 없습니다.',
          ),
        });

        final result = await t.repo.revoke('l1');

        expect(result.outcome, RevokeOutcome.alreadyGone);
        expect(result.isGone, isTrue, reason: '보호자가 원한 상태(연결 없음)가 이미 됐다');
      },
    );

    test('코드 없는 404 는 이미 끊김으로 보지 않는다 — 프록시·잘못된 주소일 수 있다', () async {
      final t = build({
        'DELETE /api/device-links/l1': const FakeHttpError(404),
      });

      final result = await t.repo.revoke('l1');

      expect(result.outcome, RevokeOutcome.failed);
    });

    test('권한이 없으면(403) 실패이고 서버가 준 이유가 담긴다', () async {
      final t = build({
        'DELETE /api/device-links/l1': const FakeHttpError(
          403,
          errorCode: 'PROFILE_ACCESS_DENIED',
          errorMessage: '이 이룸이의 정보를 볼 수 없어요.',
        ),
      });

      final result = await t.repo.revoke('l1');

      expect(result.outcome, RevokeOutcome.failed);
      expect(result.isGone, isFalse);
      expect(result.failure?.server?.code, ServerErrorCode.profileAccessDenied);
      expect(result.failure?.serverMessage, '이 이룸이의 정보를 볼 수 없어요.');
    });

    test('서버 오류(500)와 오프라인도 실패다', () async {
      final server = build({
        'DELETE /api/device-links/l1': const FakeHttpError(500),
      });
      expect((await server.repo.revoke('l1')).outcome, RevokeOutcome.failed);

      final offline = build({
        'DELETE /api/device-links/l1': const FakeOffline(),
      });
      final result = await offline.repo.revoke('l1');
      expect(result.outcome, RevokeOutcome.failed);
      expect(result.failure?.fault, NetworkFault.offline);
    });
  });

  group('이 휴대폰이 스스로 끊는다 — disconnectThisPhone', () {
    test('끊기면 로컬을 비운다 — 토큰·이룸이 정보·일과 캐시·체크 기록', () async {
      final t = build({
        'DELETE /api/device-links/current': const <String, Object?>{},
      });

      final failure = await t.repo.disconnectThisPhone();

      expect(failure, isNull);
      expect(tokens.hasSession, isFalse);
      expect(storage.nickname, isNull);
      expect(storage.character, isNull);
      expect(storage.cachedTodayRoutinesJson, isNull);
      expect(storage.getRoutineProgressJson('r1'), isNull);
    });

    test('이룸이 휴대폰 표식과 역할까지 지운다 — 남으면 연결 화면에 갇힌다 (#542)', () async {
      await storage.setSelectedRole('elumi');
      final t = build({
        'DELETE /api/device-links/current': const <String, Object?>{},
      });

      await t.repo.disconnectThisPhone();

      expect(storage.isElumiDevice, isFalse);
      expect(storage.selectedRole, isNull);
    });

    test('스스로 끊은 것에는 `연결이 끊어졌어요` 표식을 세우지 않는다', () async {
      await storage.setElumiLinkLost(true); // 전에 남은 표식도 내린다
      final t = build({
        'DELETE /api/device-links/current': const <String, Object?>{},
      });

      await t.repo.disconnectThisPhone();

      expect(storage.isElumiLinkLost, isFalse);
    });

    test('이미 끊겨 있으면(404 DEVICE_LINK_NOT_CONNECTED) 정리하고 끝낸다', () async {
      final t = build({
        'DELETE /api/device-links/current': const FakeHttpError(
          404,
          errorCode: 'DEVICE_LINK_NOT_CONNECTED',
        ),
      });

      expect(await t.repo.disconnectThisPhone(), isNull);
      expect(tokens.hasSession, isFalse);
      expect(storage.nickname, isNull);
    });

    test('토큰이 이미 죽었으면(401) 서버가 이 연결을 더는 인정하지 않는 것이라 정리하고 끝낸다', () async {
      final t = build({
        'DELETE /api/device-links/current': const FakeHttpError(401),
      });

      expect(await t.repo.disconnectThisPhone(), isNull);
      expect(tokens.hasSession, isFalse);
    });

    for (final (name, response) in [
      ('서버 오류(500)', const FakeHttpError(500)),
      (
        '권한 없음(403)',
        const FakeHttpError(403, errorCode: 'DEVICE_LINK_ONLY_FOR_ELUMI'),
      ),
      ('오프라인', const FakeOffline()),
    ]) {
      test('$name 이면 아무것도 지우지 않고 이유를 돌려준다 — 서버에는 연결이 살아 있다', () async {
        final t = build({'DELETE /api/device-links/current': response});

        final failure = await t.repo.disconnectThisPhone();

        expect(failure, isNotNull);
        expect(
          tokens.hasSession,
          isTrue,
          reason: '지우고 나면 보호자 쪽에는 계속 연결됨으로 남는다',
        );
        expect(storage.nickname, '하늘이');
        expect(storage.cachedTodayRoutinesJson, isNotNull);
      });
    }
  });

  group('연결이 밖에서 끊겼다 — releaseThisPhone(lost: true)', () {
    test('로컬을 비우고 `연결이 끊어졌어요` 표식을 세운다', () async {
      final t = build(const {});

      await t.repo.releaseThisPhone(lost: true);

      expect(storage.isElumiLinkLost, isTrue);
      expect(storage.nickname, isNull);
      expect(storage.cachedTodayRoutinesJson, isNull);
      expect(storage.isElumiDevice, isTrue);
    });

    test('다시 연결에 성공하면 표식이 내려간다', () async {
      await storage.setElumiLinkLost(true);
      final t = build({
        'POST /api/device-links/redeem': const {
          'accessToken': 'a2',
          'refreshToken': 'r2',
        },
        'GET /api/member/me': const {'nickname': '하늘이', 'character': 'FOX'},
      });

      final result = await t.repo.redeem('A7K3M9');

      expect(result.outcome, RedeemOutcome.linked);
      expect(storage.isElumiLinkLost, isFalse);
    });
  });

  group('연결 상태 — statusResult', () {
    test('실패를 비어 있는 상태와 구분한다 — 연결된 보호자에게 `연결하기`가 보이면 안 된다', () async {
      final t = build({'GET /api/device-links': const FakeHttpError(500)});

      final result = await t.repo.statusResult();

      expect(result.isOk, isFalse);
      expect(result.failure, isNotNull);
    });

    test('연결된 휴대폰 목록을 읽는다', () async {
      final t = build({
        'GET /api/device-links': const {
          'devices': [
            {'linkId': 'l1', 'linkedAt': '2026-09-18T10:31:00'},
          ],
          'pendingExpiresAt': null,
        },
      });

      final result = await t.repo.statusResult();

      expect(result.isOk, isTrue);
      expect(result.value!.devices.single.linkId, 'l1');
    });
  });
}
