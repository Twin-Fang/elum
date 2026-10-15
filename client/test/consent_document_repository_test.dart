import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

/// 약관 3층 폴백 (이슈 #278).
///
/// **어떤 실패에도 읽을 것이 남아야 한다.** 읽을 수 없는 상태에서 받은 동의는
/// 고지로 성립하지 않으므로, 약관을 못 받으면 가입 자체가 막힌다.
void main() {
  /// 서버가 줄 법한 한 벌.
  Map<String, dynamic> serverPayload({String version = '2026-10-01'}) => {
    'version': version,
    'documents': [
      {
        'key': 'termsAgreed',
        'label': '서비스 이용약관',
        'required': true,
        'summary': '요약',
        'body': '서버가 준 본문',
        'version': version,
      },
      {
        'key': 'marketingAgreed',
        'label': '서비스 소식 받기',
        'required': false,
        'summary': '요약',
        'body': '선택 항목 본문',
        'version': '2026-09-18',
      },
    ],
  };

  /// [handler]가 응답을 정한다. 네트워크에 나가지 않는다.
  Dio dioWith(Future<Response<Map<String, dynamic>>> Function() handler) {
    final dio = Dio();
    dio.httpClientAdapter = _NeverCalledAdapter();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, h) async {
          try {
            final response = await handler();
            h.resolve(Response(requestOptions: options, data: response.data));
          } catch (e) {
            h.reject(DioException(requestOptions: options, error: e));
          }
        },
      ),
    );
    return dio;
  }

  Dio failingDio() =>
      dioWith(() async => throw Exception('서버를 못 봤다'));

  group('서버 → 캐시 → 번들 순으로 떨어진다', () {

    test('서버를 못 보면 캐시를 쓴다', () async {
      final storage = InMemoryStorage();
      await storage.setCachedConsentJson(
        jsonEncode(serverPayload(version: '2026-09-30')),
      );
      final repo = ConsentDocumentRepository(
        dio: failingDio(),
        storage: storage,
      );

      final bundle = await repo.load();

      expect(bundle.source, ConsentSource.cache);
      expect(bundle.version, '2026-09-30');
    });

    test('서버도 캐시도 없으면 앱에 담긴 기본값을 쓴다', () async {
      final repo = ConsentDocumentRepository(
        dio: failingDio(),
        storage: InMemoryStorage(),
      );

      final bundle = await repo.load();

      // 여기서 예외가 나거나 빈 목록이 오면 첫 실행 + 비행기 모드에서
      // 가입이 통째로 막힌다.
      expect(bundle.source, ConsentSource.bundled);
      expect(bundle.version, consentVersion);
      expect(bundle.items, isNotEmpty);
    });
  });

  group('이상한 응답을 받아도 화면이 비지 않는다', () {
    test('깨진 캐시는 무시하고 기본값으로 간다', () async {
      final storage = InMemoryStorage();
      await storage.setCachedConsentJson('{ 이건 JSON이 아니다');
      final repo = ConsentDocumentRepository(
        dio: failingDio(),
        storage: storage,
      );

      expect((await repo.load()).source, ConsentSource.bundled);
    });

    test('항목이 하나라도 깨지면 응답을 통째로 버린다', () async {
      // 일부만 살리면 **동의해야 할 항목이 화면에서 조용히 사라진다.**
      final broken = serverPayload();
      (broken['documents'] as List)[0] = {'key': 'termsAgreed'}; // body 없음
      final repo = ConsentDocumentRepository(
        dio: dioWith(
          () async => Response(requestOptions: RequestOptions(), data: broken),
        ),
        storage: InMemoryStorage(),
      );

      expect((await repo.load()).source, ConsentSource.bundled);
    });

    test('버전이 없으면 받지 않는다 — 무엇에 동의했는지 기록할 수 없다', () async {
      final noVersion = serverPayload();
      noVersion.remove('version');
      final repo = ConsentDocumentRepository(
        dio: dioWith(
          () async =>
              Response(requestOptions: RequestOptions(), data: noVersion),
        ),
        storage: InMemoryStorage(),
      );

      expect((await repo.load()).source, ConsentSource.bundled);
    });

  });



}

/// 어댑터까지 내려가면 실제 네트워크다. 그 전에 인터셉터가 끊어야 한다.
class _NeverCalledAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancelFuture) async {
    fail('실제 네트워크로 나갔다');
  }
}

