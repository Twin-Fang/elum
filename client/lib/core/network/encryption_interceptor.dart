import 'dart:convert';

import 'package:dio/dio.dart';

import '../security/aidlp_crypto.dart';

/// AI DLP 진입점 요청 본문을 AES-GCM으로 암호화해 전송한다.
///
/// 대상 3경로의 POST 요청만 봉투로 치환하고 재전송 방지 헤더를 붙인다.
/// secret이 비었거나 대상이 아니면 요청을 그대로 흘려보낸다(평문 → 서버도 통과, 데모 안전).
class EncryptionInterceptor extends Interceptor {
  EncryptionInterceptor({required String secret}) : _secret = secret;

  final String _secret;

  // 정확히 이 경로의 POST만 암호화한다. baseUrl을 뺀 path 기준.
  static const _targetPaths = {
    '/api/routines',
    '/api/routines/questions',
    '/api/internal/sensitive-check',
  };

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final isTarget = options.method.toUpperCase() == 'POST' && _targetPaths.contains(options.path);
    if (!isTarget || _secret.isEmpty || options.data is! Map) {
      handler.next(options); // 그대로 통과
      return;
    }

    try {
      final plaintext = jsonEncode(options.data);
      final sealed = await AidlpCrypto.seal(plaintext, secret: _secret);
      options.data = {'encrypted': sealed.envelope.toJson()};
      options.headers['X-Elum-Timestamp'] = sealed.timestamp;
      options.headers['X-Elum-Nonce'] = sealed.nonce;
      options.headers['X-Elum-Signature'] = sealed.signature;
      handler.next(options);
    } catch (_) {
      // 암호화 실패해도 데모를 막지 않는다 — 평문 그대로 보내 서버 fallback/로컬 fallback에 맡긴다.
      handler.next(options);
    }
  }
}
