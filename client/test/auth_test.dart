import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

/// 소셜 로그인 인증 테스트.
///
/// 제공자 SDK는 대역으로 바꿔 넣는다. 실제 카카오·구글 화면을 띄울 수 없고,
/// 검증할 것은 **SDK가 준 토큰을 서버 토큰으로 바꾸고 다음 화면을 정하는 부분**이다.
void main() {
  late _FakeAdapter adapter;
  late Dio dio;
  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;

  setUp(() {
    adapter = _FakeAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    storage = InMemoryStorage();
    tokens = InMemoryTokenStore();
  });

  AuthRepository buildRepo(OAuthSdkOutcome sdkResult) => AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(sdkResult),
      );

  Map<String, dynamic> tokenBody(String access, String refresh) => {
        'accessToken': access,
        'tokenType': 'Bearer',
        'expiresIn': 86400000,
        'refreshToken': refresh,
      };

  Map<String, dynamic> memberBody({
    bool consented = true,
    String? nickname,
  }) =>
      {
        'id': 'm1',
        'username': 'kakao_123',
        'requiredConsentsCompleted': consented,
        'nickname': nickname,
      };

  group('소셜 로그인', () {
    test('토큰을 받아 저장하고, 동의 전이면 동의 화면으로 보낸다', () async {
      adapter
        ..stub('/api/auth/oauth/kakao', 200, tokenBody('access-1', 'refresh-1'))
        ..stub('/api/member/me', 200, memberBody(consented: false));

      final outcome = await buildRepo(const OAuthSdkSuccess('kakao-token'))
          .signInWith(OAuthProvider.kakao);

      expect(outcome, AuthOutcome.consentRequired);
      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
    });

    test('동의를 마쳤고 아이 정보가 없으면 온보딩으로 보낸다', () async {
      adapter
        ..stub('/api/auth/oauth/google', 200, tokenBody('access-1', 'refresh-1'))
        ..stub('/api/member/me', 200, memberBody(nickname: null));

      final outcome = await buildRepo(const OAuthSdkSuccess('id-token'))
          .signInWith(OAuthProvider.google);

      expect(outcome, AuthOutcome.onboarding);
    });

    test('아이 정보까지 있으면 홈으로 보내고 이름을 로컬에 되살린다', () async {
      adapter
        ..stub('/api/auth/oauth/kakao', 200, tokenBody('access-1', 'refresh-1'))
        ..stub('/api/member/me', 200, memberBody(nickname: '하늘이'));

      final outcome = await buildRepo(const OAuthSdkSuccess('kakao-token'))
          .signInWith(OAuthProvider.kakao);

      expect(outcome, AuthOutcome.home);
      // 재설치한 사용자도 아이 이름이 화면에 바로 보여야 한다
      expect(storage.nickname, '하늘이');
    });

    test('성공하면 다음 화면에서 안내할 수 있게 로그인 수단을 남긴다', () async {
      adapter
        ..stub('/api/auth/oauth/naver', 200, tokenBody('access-1', 'refresh-1'))
        ..stub('/api/member/me', 200, memberBody(nickname: '하늘이'));

      await buildRepo(const OAuthSdkSuccess('naver-token'))
          .signInWith(OAuthProvider.naver);

      expect(storage.lastLoginProvider, 'naver');
    });

    test('사용자가 제공자 화면을 닫으면 서버를 부르지 않는다', () async {
      final outcome = await buildRepo(const OAuthSdkCancelled())
          .signInWith(OAuthProvider.kakao);

      expect(outcome, AuthOutcome.cancelled);
      expect(adapter.pathsCalled, isEmpty);
      expect(tokens.hasSession, isFalse);
    });

    test('같은 이메일이 다른 제공자로 가입돼 있으면 합치지 않고 알린다', () async {
      // 서버가 이메일로 계정을 병합하지 않기 때문에 409가 온다.
      adapter.stub('/api/auth/oauth/google', 409, {'errorCode': 'OAUTH_EMAIL_CONFLICT'});

      final outcome = await buildRepo(const OAuthSdkSuccess('id-token'))
          .signInWith(OAuthProvider.google);

      expect(outcome, AuthOutcome.emailConflict);
      expect(tokens.hasSession, isFalse);
    });

    test('서버에 닿지 못하면 인증 실패와 구분해 알린다', () async {
      adapter.stubConnectionError('/api/auth/oauth/kakao');

      final outcome = await buildRepo(const OAuthSdkSuccess('kakao-token'))
          .signInWith(OAuthProvider.kakao);

      // 네트워크 문제인데 "다시 로그인하라"고 하면 사용자는 헛수고를 한다
      expect(outcome, AuthOutcome.offline);
    });

    test('SDK가 실패하면 서버를 부르지 않는다', () async {
      final outcome = await buildRepo(const OAuthSdkFailure('SDK-KAKAO'))
          .signInWith(OAuthProvider.kakao);

      expect(outcome, AuthOutcome.failed);
      expect(adapter.pathsCalled, isEmpty);
    });
  });

  group('토큰 갱신', () {
    test('갱신하면 리프레시 토큰도 새 값으로 바뀐다 (회전)', () async {
      tokens = InMemoryTokenStore(accessToken: 'old-a', refreshToken: 'old-r');
      adapter.stub('/api/auth/refresh', 200, tokenBody('new-a', 'new-r'));

      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );
      final access = await repo.refreshAccessToken();

      expect(access, 'new-a');
      // 옛 값을 그대로 두면 다음 갱신에서 재사용으로 감지돼 로그아웃된다
      expect(tokens.refreshToken, 'new-r');
    });

    test('동시에 여러 번 요청해도 서버에는 한 번만 나간다', () async {
      // 회전 방식이라 같은 리프레시 토큰이 두 번 나가면 서버가 탈취로 보고
      // 계정의 모든 세션을 끊는다. 홈 화면이 API를 동시에 부를 때 실제로 생긴다.
      tokens = InMemoryTokenStore(accessToken: 'old-a', refreshToken: 'old-r');
      adapter.stub('/api/auth/refresh', 200, tokenBody('new-a', 'new-r'));

      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );

      final results = await Future.wait([
        repo.refreshAccessToken(),
        repo.refreshAccessToken(),
        repo.refreshAccessToken(),
      ]);

      expect(results, ['new-a', 'new-a', 'new-a']);
      expect(
        adapter.pathsCalled.where((p) => p == '/api/auth/refresh').length,
        1,
      );
    });

    test('갱신이 401이면 세션이 끝난 것이므로 토큰을 지운다', () async {
      tokens = InMemoryTokenStore(accessToken: 'old-a', refreshToken: 'old-r');
      adapter.stub('/api/auth/refresh', 401, {'errorCode': 'REFRESH_TOKEN_REUSED'});

      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );
      final access = await repo.refreshAccessToken();

      expect(access, isNull);
      expect(tokens.hasSession, isFalse);
    });

    test('서버에 닿지 못한 것뿐이면 토큰을 지우지 않는다', () async {
      // 네트워크 문제로 로그아웃시키면 지하철에서 앱을 열 때마다 튕긴다
      tokens = InMemoryTokenStore(accessToken: 'old-a', refreshToken: 'old-r');
      adapter.stubConnectionError('/api/auth/refresh');

      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );
      final access = await repo.refreshAccessToken();

      expect(access, isNull);
      expect(tokens.hasSession, isTrue);
    });

    test('리프레시 토큰이 없으면 서버를 부르지 않는다', () async {
      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );
      final access = await repo.refreshAccessToken();

      expect(access, isNull);
      expect(adapter.pathsCalled, isEmpty);
    });
  });

  group('로그아웃', () {
    test('서버 세션을 끊고 로컬을 비운다', () async {
      tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      await storage.setNickname('하늘이');
      adapter.stub('/api/auth/logout', 204, <String, dynamic>{});

      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );
      await repo.logout();

      expect(adapter.pathsCalled, contains('/api/auth/logout'));
      expect(tokens.hasSession, isFalse);
      expect(storage.nickname, isNull);
    });

    test('서버 요청이 실패해도 로컬은 반드시 비운다', () async {
      // 로컬에 남으면 사용자는 로그아웃했다고 생각하는데 앱은 로그인 상태로 돈다
      tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
      adapter.stubConnectionError('/api/auth/logout');

      final repo = AuthRepository(
        dio: dio,
        storage: storage,
        tokens: tokens,
        sdk: _FakeSdk(const OAuthSdkCancelled()),
      );
      await repo.logout();

      expect(tokens.hasSession, isFalse);
    });
  });
}

/// 제공자 화면을 띄우지 않는 SDK 대역. 정해진 결과를 그대로 돌려준다.
class _FakeSdk implements OAuthSdk {
  _FakeSdk(this.result);

  final OAuthSdkOutcome result;

  @override
  Future<OAuthSdkOutcome> signIn(OAuthProvider provider) async => result;
}

class _FakeAdapter implements HttpClientAdapter {
  final _single = <String, (int, Map<String, dynamic>)>{};
  final _sequences = <String, List<(int, Map<String, dynamic>)>>{};

  final pathsCalled = <String>[];
  var lastHeaders = <String, dynamic>{};

  /// 마지막 요청의 HTTP 메서드. 경로가 같아도 메서드가 다르면 서버가 405를 준다.
  var lastMethod = '';

  /// 마지막 요청 본문. 어떤 자격증명을 보냈는지 검증한다.
  var lastBody = <String, dynamic>{};

  /// 연결 자체가 실패하는 경로. 응답을 못 받는 상황(DNS·오프라인)을 흉내낸다.
  final _connectionErrors = <String>{};

  void stub(String path, int status, Map<String, dynamic> body) {
    _single[path] = (status, body);
  }

  /// 서버에 닿지 못하게 만든다. 실기기 오프라인과 같은 DioException이 난다.
  void stubConnectionError(String path) {
    _connectionErrors.add(path);
  }

  /// 호출 순서대로 다른 응답을 돌려준다 (401 → 200 재시도 검증용)
  void stubSequence(String path, List<(int, Map<String, dynamic>)> responses) {
    _sequences[path] = [...responses];
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    pathsCalled.add(options.path);
    lastMethod = options.method;
    lastHeaders = Map<String, dynamic>.from(options.headers);
    if (options.data case final Map<String, dynamic> body) {
      lastBody = Map<String, dynamic>.from(body);
    }

    if (_connectionErrors.contains(options.path)) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      );
    }

    final sequence = _sequences[options.path];
    final (status, body) = switch (sequence) {
      final list when list != null && list.isNotEmpty => list.removeAt(0),
      _ => _single[options.path] ?? (404, <String, dynamic>{}),
    };

    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
