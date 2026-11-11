import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../member/domain/member_subscription.dart';
import '../domain/store_verification.dart';

/// 스토어 결제 확인 요청 — 서버 `SubscriptionStoreController`
///
/// 출처: server/.../license/application/controller/SubscriptionStoreController.java
/// 예외를 올리지 않고 [Attempt] 로 돌려줌. 응답 모양이 다르면 실패 (거래를 마무리하지 않게)
class SubscriptionVerifyRepository {
  SubscriptionVerifyRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _repo = 'SubscriptionVerifyRepository';

  /// App Store: `Transaction.jwsRepresentation`
  Future<Attempt<StoreVerificationResult>> verifyApple(String signedTransaction) =>
      guarded(_repo, 'verifyApple', () async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/api/subscriptions/apple',
          data: {'signedTransaction': signedTransaction},
        );
        return _parse(response.data);
      }, describe: _describe);

  /// Google Play: 구매 토큰 + 상품 id
  Future<Attempt<StoreVerificationResult>> verifyGoogle({
    required String purchaseToken,
    required String productId,
  }) => guarded(_repo, 'verifyGoogle', () async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/subscriptions/google',
      data: {'purchaseToken': purchaseToken, 'productId': productId},
    );
    return _parse(response.data);
  }, describe: _describe);

  static StoreVerificationResult _parse(Map<String, dynamic>? body) {
    final verification = StoreVerification.tryParse(body?['verification']);
    if (verification == null) {
      throw const FormatException('verification is missing or unknown');
    }
    return StoreVerificationResult(
      verification: verification,
      subscription: MemberSubscription.tryParse(body?['subscription']),
    );
  }

  // 로그에는 결과 값만 (증빙 원문 없음)
  static String _describe(StoreVerificationResult result) =>
      result.verification.wire;
}

final subscriptionVerifyRepositoryProvider = Provider<SubscriptionVerifyRepository>(
  (ref) => SubscriptionVerifyRepository(dio: ref.watch(dioProvider)),
);
