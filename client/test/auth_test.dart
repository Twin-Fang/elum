import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:elum/core/network/auth_interceptor.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// 아이 이름을 아이디로 쓰는 인증 테스트.
///
/// Figma에 로그인 화면이 없어 온보딩에서 받는 아이 이름을 아이디로 쓴다.
/// 비밀번호는 고정값이라 기기가 달라도 같은 이름이면 같은 계정이다.
void main() {
  /// 요청을 가로채 미리 정한 응답을 돌려주는 어댑터.
  /// 실 서버를 때리면 테스트가 네트워크에 의존하게 된다.
  late _FakeAdapter adapter;
  late Dio dio;
  late InMemoryStorage storage;

  setUp(() {
    adapter = _FakeAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    storage = InMemoryStorage();
  });

  /// 로그인 성공 응답
  Map<String, dynamic> loginBody(String token) => {
        'accessToken': token,
        'tokenType': 'Bearer',
        'expiresIn': 3600000,
      };

  group('AuthRepository — 아이 이름이 곧 아이디', () {
    test('새 이름이면 계정을 만들고 온보딩을 계속한다', () async {
      adapter
        ..stub('/api/auth/signup', 201, <String, dynamic>{})
        ..stub('/api/auth/login', 200, loginBody('token-1'));

      final repo = AuthRepository(dio: dio, storage: storage);
      final outcome = await repo.signInWithName('하늘이별');

      expect(outcome, AuthOutcome.created);
      expect(storage.accessToken, 'token-1');
    });

    test('이미 있는 이름이면 로그인해 기존 계정으로 복귀한다', () async {
      // 서버는 중복 아이디에 409를 준다. 오류가 아니라 "기존 사용자" 신호다.
      adapter
        ..stub('/api/auth/signup', 409, {'errorCode': 'DUPLICATE_USERNAME'})
        ..stub('/api/auth/login', 200, loginBody('token-2'));

      final repo = AuthRepository(dio: dio, storage: storage);
      final outcome = await repo.signInWithName('하늘이별');

      expect(outcome, AuthOutcome.restored);
      expect(storage.accessToken, 'token-2');
    });

    test('아이디·비밀번호로 이름과 고정값을 보낸다', () async {
      adapter
        ..stub('/api/auth/signup', 201, <String, dynamic>{})
        ..stub('/api/auth/login', 200, loginBody('token-1'));

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.signInWithName('하늘이별');

      // 기기가 달라도 같은 이름이면 같은 계정이어야 한다
      expect(adapter.lastBody['username'], '하늘이별');
      expect(adapter.lastBody['password'], AuthRepository.fixedPassword);
    });

    test('고정 비밀번호가 서버 제약(8자 이상)을 지킨다', () {
      // "0000"은 실측 결과 400이다
      expect(AuthRepository.fixedPassword.length, greaterThanOrEqualTo(8));
    });

    test('이름 앞뒤 공백은 제거하고 보낸다', () async {
      adapter
        ..stub('/api/auth/signup', 201, <String, dynamic>{})
        ..stub('/api/auth/login', 200, loginBody('token-1'));

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.signInWithName('  하늘이별  ');

      // 공백이 섞이면 같은 이름인데 다른 계정이 된다
      expect(adapter.lastBody['username'], '하늘이별');
    });

    test('이름이 비면 네트워크를 타지 않는다', () async {
      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.signInWithName('   '), AuthOutcome.failed);
      expect(adapter.pathsCalled, isEmpty);
    });

    test('로그인이 실패해도 예외를 던지지 않는다', () async {
      // 데모는 어떤 실패에도 끝까지 진행되어야 한다 (docs 원칙 6번).
      adapter
        ..stub('/api/auth/signup', 500, <String, dynamic>{})
        ..stub('/api/auth/login', 500, <String, dynamic>{});

      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.signInWithName('하늘이별'), AuthOutcome.failed);
    });

    test('이름이 4자 미만이면 서버 400을 그대로 실패로 전한다', () async {
      // 서버가 username을 4~20자로 제한한다. 클라에서 우회하지 않는다.
      adapter
        ..stub('/api/auth/signup', 400, {'errorCode': 'INVALID_INPUT_VALUE'})
        ..stub('/api/auth/login', 401, <String, dynamic>{});

      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.signInWithName('하늘이'), AuthOutcome.failed);
    });

    /// 실기기에서 INTERNET 권한이 없어 DNS부터 막혔을 때, 화면이 "이름을 4자
    /// 이상으로" 안내해 사용자가 이름만 계속 고치는 문제가 있었다.
    /// 네트워크 실패는 이름 문제와 구분되어야 한다.
    test('서버에 닿지 못하면 offline으로 구분한다', () async {
      adapter
        ..stubConnectionError('/api/auth/signup')
        ..stubConnectionError('/api/auth/login');

      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.signInWithName('하늘이별'), AuthOutcome.offline);
    });

    test('가입 단계에서 끊기면 로그인을 시도하지 않는다', () async {
      // 서버에 못 닿는 게 확실하므로 같은 요청을 한 번 더 보낼 이유가 없다.
      adapter.stubConnectionError('/api/auth/signup');

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.signInWithName('하늘이별');

      expect(adapter.pathsCalled, isNot(contains('/api/auth/login')));
    });

    test('가입은 됐는데 로그인에서 끊기면 offline이다', () async {
      adapter
        ..stub('/api/auth/signup', 201, <String, dynamic>{})
        ..stubConnectionError('/api/auth/login');

      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.signInWithName('하늘이별'), AuthOutcome.offline);
    });

    test('서버가 응답한 실패는 offline이 아니다', () async {
      // 400·500은 서버까지 닿은 것이다. 네트워크 안내를 하면 오히려 혼란스럽다.
      adapter
        ..stub('/api/auth/signup', 400, {'errorCode': 'INVALID_INPUT_VALUE'})
        ..stub('/api/auth/login', 401, <String, dynamic>{});

      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.signInWithName('하늘이'), AuthOutcome.failed);
    });

    test('저장된 이름으로 토큰을 재발급한다', () async {
      await storage.setNickname('하늘이별');
      adapter.stub('/api/auth/login', 200, loginBody('fresh'));

      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.reauthenticate(), 'fresh');
      // 재발급은 가입을 다시 시도하지 않는다
      expect(adapter.pathsCalled, isNot(contains('/api/auth/signup')));
    });

    test('이름이 없으면 재발급하지 않는다', () async {
      final repo = AuthRepository(dio: dio, storage: storage);

      expect(await repo.reauthenticate(), isNull);
      expect(adapter.pathsCalled, isEmpty);
    });

    test('hasToken이 라우팅 판단 기준이 된다', () async {
      final repo = AuthRepository(dio: dio, storage: storage);
      expect(repo.hasToken, isFalse);

      await storage.setAccessToken('token-1');
      expect(repo.hasToken, isTrue);

      // 로그아웃하면 시작 화면으로 돌아가야 한다
      await storage.clearAll();
      expect(repo.hasToken, isFalse);
    });
  });

  group('AuthInterceptor — 토큰 만료 대응', () {
    test('토큰이 있으면 Authorization 헤더를 붙인다', () async {
      await storage.setAccessToken('token-1');
      adapter.stub('/api/member/me', 200, {'id': 'm1'});

      dio.interceptors.add(
        AuthInterceptor(
          storage: storage,
          dio: dio,
          reauthenticate: () async => 'token-1',
        ),
      );
      await dio.get<dynamic>('/api/member/me');

      expect(adapter.lastHeaders['Authorization'], 'Bearer token-1');
    });

    test('401이면 재발급 후 원요청을 재시도한다', () async {
      await storage.setAccessToken('expired');
      // 첫 호출은 401, 재시도는 200
      adapter.stubSequence('/api/member/me', [
        (401, <String, dynamic>{}),
        (200, {'id': 'm1'}),
      ]);

      var reauthCount = 0;
      dio.interceptors.add(
        AuthInterceptor(
          storage: storage,
          dio: dio,
          reauthenticate: () async {
            reauthCount++;
            await storage.setAccessToken('fresh');
            return 'fresh';
          },
        ),
      );

      final res = await dio.get<dynamic>('/api/member/me');

      expect(res.statusCode, 200);
      expect(reauthCount, 1);
      // 재시도는 새 토큰으로 나가야 한다
      expect(adapter.lastHeaders['Authorization'], 'Bearer fresh');
    });

    test('재시도가 또 401이면 무한 루프 없이 실패한다', () async {
      await storage.setAccessToken('expired');
      adapter.stub('/api/member/me', 401, <String, dynamic>{});

      var reauthCount = 0;
      dio.interceptors.add(
        AuthInterceptor(
          storage: storage,
          dio: dio,
          reauthenticate: () async {
            reauthCount++;
            await storage.setAccessToken('still-bad');
            return 'still-bad';
          },
        ),
      );

      await expectLater(
        dio.get<dynamic>('/api/member/me'),
        throwsA(isA<DioException>()),
      );
      // 재발급은 딱 한 번만 시도한다
      expect(reauthCount, 1);
    });

    test('재발급이 실패하면 원래 401을 그대로 돌려준다', () async {
      await storage.setAccessToken('expired');
      adapter.stub('/api/member/me', 401, <String, dynamic>{});

      dio.interceptors.add(
        AuthInterceptor(
          storage: storage,
          dio: dio,
          reauthenticate: () async => null,
        ),
      );

      await expectLater(
        dio.get<dynamic>('/api/member/me'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
    });
  });

  /// 회원삭제는 개발자 도구 플로팅 버튼에서 쓰는 기능이다.
  ///
  /// 서버 계약: `DELETE /api/member/me` → 204 No Content, body 없음.
  /// 출처: server/.../member/application/controller/MemberController.java
  ///
  /// 경로나 메서드가 어긋나면 조용히 실패한다 — deleteAccount()가 예외를
  /// 삼키기 때문에 로컬만 지워지고 서버에는 계정이 남는다. 그래서 테스트로 고정한다.
  group('AuthRepository.deleteAccount — 서버 계약', () {
    test('DELETE /api/member/me를 호출한다', () async {
      adapter.stub('/api/member/me', 204, {});
      storage
        ..setAccessToken('token')
        ..setNickname('하늘이별');

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.deleteAccount();

      expect(adapter.pathsCalled, contains('/api/member/me'));
      expect(adapter.lastMethod, 'DELETE');
    });

    test('삭제 후 토큰과 이름이 모두 지워진다', () async {
      adapter.stub('/api/member/me', 204, {});
      storage
        ..setAccessToken('token')
        ..setNickname('하늘이별');

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.deleteAccount();

      // 토큰만 지우고 이름이 남으면 AuthInterceptor가 재발급을 시도해
      // 지워진 계정으로 되살아난다. 둘 다 지워져야 한다.
      expect(storage.accessToken, isNull);
      expect(storage.nickname, isNull);
    });

    test('서버가 실패해도 로컬은 반드시 지운다', () async {
      // 스텁을 등록하지 않으면 어댑터가 404를 준다
      storage
        ..setAccessToken('token')
        ..setNickname('하늘이별');

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.deleteAccount();

      // 토큰이 남으면 지워진 계정으로 계속 401을 맞는다
      expect(storage.accessToken, isNull);
    });

    test('삭제 후에는 토큰 재발급이 시도되지 않는다', () async {
      adapter.stub('/api/member/me', 204, {});
      storage
        ..setAccessToken('token')
        ..setNickname('하늘이별');

      final repo = AuthRepository(dio: dio, storage: storage);
      await repo.deleteAccount();

      // 이름이 지워졌으므로 재발급할 방법이 없다 → 무한 루프가 생기지 않는다
      expect(await repo.reauthenticate(), isNull);
      expect(repo.hasToken, isFalse);
    });
  });
}

/// 경로별로 정해둔 응답을 돌려주는 가짜 어댑터.
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
