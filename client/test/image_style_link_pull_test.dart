import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

/// 이룸이 휴대폰이 연결될 때 보호자가 정한 그림 방식도 내려받는다 (#458).
///
/// 이 휴대폰은 온보딩을 한 적이 없어 로컬 값이 비어 있다. 이룸이 화면은 방식을 바꾸지는
/// 못해도 보호자가 정한 방식을 알고 있어야 한다.
void main() {
  late InMemoryStorage storage;

  DeviceLinkRepository repo(Map<String, Object?> me) {
    storage = InMemoryStorage();
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = FakeAdapter({
        'POST /api/device-links/redeem': {
          'accessToken': 'a',
          'refreshToken': 'r',
        },
        'GET /api/member/me': me,
      });
    return DeviceLinkRepository(dio: dio, tokens: _Tokens(), storage: storage);
  }

  test('연결하면 서버의 그림 방식을 로컬에 담는다', () async {
    final r = repo({'nickname': '하늘이', 'imageStyle': 'PHOTO_ONLY'});

    expect((await r.redeem('ABCD')).outcome, RedeemOutcome.linked);

    expect(storage.imageStyle, 'PHOTO_ONLY');
  });

  // E1·E2 — 옛 서버(필드 없음)·새 값이어도 연결은 성공하고 로컬 값은 비워 둔다(읽는 쪽이 만화로 처리).
  test('E1·E2 필드가 없거나 모르는 값이면 담지 않는다', () async {
    final none = repo({'nickname': '하늘이'});
    await none.redeem('ABCD');
    expect(storage.imageStyle, isNull);

    final unknown = repo({'nickname': '하늘이', 'imageStyle': 'ANIME'});
    await unknown.redeem('ABCD');
    expect(storage.imageStyle, isNull);
  });
}

class _Tokens implements TokenStore {
  @override
  String? accessToken;
  @override
  String? refreshToken;
  @override
  bool get hasSession => refreshToken != null;
  @override
  Future<void> load() async {}
  @override
  Future<void> save({required String accessToken, required String refreshToken}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {}
}
