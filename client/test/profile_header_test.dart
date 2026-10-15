import 'package:dio/dio.dart';
import 'package:elum/core/network/profile_header_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

/// 고른 이룸이를 모든 요청에 `X-Profile-Id` 로 싣는 인터셉터 (#362 · 서버 #360).
///
/// 헤더가 빠지면 서버는 "가장 먼저 합류한 이룸이"를 쓴다. 이룸이를 바꿨는데 일과가
/// 안 바뀌는 조용한 결함이라, 실리는 자리와 **싣지 않는 자리**를 함께 고정한다.
void main() {
  late FakeAdapter adapter;
  String? selected;
  final lost = <String>[];
  var noProfile = 0;

  Dio build(Map<String, Object?> routes) {
    adapter = FakeAdapter(routes);
    return Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        ProfileHeaderInterceptor(
          profileId: () => selected,
          onProfileLost: lost.add,
          onNoProfile: () => noProfile++,
        ),
      );
  }

  setUp(() {
    selected = null;
    lost.clear();
    noProfile = 0;
  });

  test('고른 이룸이가 있으면 요청마다 X-Profile-Id 를 싣는다', () async {
    selected = 'p-2';
    final dio = build({'GET /api/routines/today': <Object>[]});

    await dio.get<dynamic>('/api/routines/today');

    expect(adapter.sentHeaders['GET /api/routines/today']!['X-Profile-Id'], 'p-2');
  });

  test('실은 이룸이가 403 PROFILE_ACCESS_DENIED 면 잃었다고 알린다 (다른 휴대폰에서 나갔다)', () async {
    selected = 'p-2';
    final dio = build({
      'GET /api/routines/today': const FakeHttpError(
        403,
        errorCode: 'PROFILE_ACCESS_DENIED',
        errorMessage: '이 이룸이의 정보를 볼 수 없어요.',
      ),
    });

    await expectLater(dio.get<dynamic>('/api/routines/today'), throwsA(isA<DioException>()));

    expect(lost, ['p-2']);
    expect(noProfile, 0);
  });

  test('헤더 없이 404 PROFILE_NOT_FOUND 면 이룸이가 없다고 알린다 (E29)', () async {
    final dio = build({
      'GET /api/routines/today': const FakeHttpError(
        404,
        errorCode: 'PROFILE_NOT_FOUND',
        errorMessage: '등록된 이룸이가 없어요.',
      ),
    });

    await expectLater(dio.get<dynamic>('/api/routines/today'), throwsA(isA<DioException>()));

    expect(noProfile, 1);
    expect(lost, isEmpty);
  });

}
