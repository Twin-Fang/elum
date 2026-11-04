import 'package:flutter/foundation.dart';

/// 결제한 스토어 2개: App Store, Google Play
enum StorePlatform { appStore, googlePlay }

/// 스토어가 알린 구매 상태 5개: 진행 중(허락 대기), 결제됨, 복원됨, 취소, 실패
enum StorePurchaseStatus { pending, purchased, restored, canceled, error }

/// 스토어가 알린 구매 한 건 (패키지 타입을 응용 계층에 흘리지 않으려는 모양)
///
/// [handle] 은 스토어 원본 객체다. 거래 마무리(finish·acknowledge)에만 다시 넘긴다.
@immutable
class StorePurchaseUpdate {
  const StorePurchaseUpdate({
    required this.platform,
    required this.status,
    required this.productId,
    required this.verificationToken,
    required this.handle,
    this.transactionId,
    this.isAcknowledged = false,
    this.errorCode,
  });

  final StorePlatform platform;
  final StorePurchaseStatus status;
  final String productId;

  /// 서버에 보낼 증빙: Apple 은 거래 JWS, Google 은 구매 토큰. 실패·취소면 빈 문자열
  final String verificationToken;

  /// Apple 거래 id. Google 은 null
  final String? transactionId;

  /// Google: 이미 acknowledge 된 구매인가 (Apple 은 늘 false)
  final bool isAcknowledged;

  /// 스토어 실패 코드 (로그·배지용)
  final String? errorCode;

  final Object handle;

  /// 같은 구매를 두 번 확인하지 않기 위한 열쇠 (스토어 + 증빙)
  String get dedupeKey => '${platform.name}:$verificationToken';

  bool get hasVerificationToken => verificationToken.isNotEmpty;
}

/// 스토어 계정 토큰(Apple `appAccountToken` · Google `obfuscatedAccountId`)으로 쓸 수 있는 회원 id 인가
///
/// Apple 은 UUID 가 아니면 조용히 버린다 > 미리 막는다 (서버 회원 id 는 UUID 문자열)
bool isPurchaseAccountToken(String? memberId) =>
    memberId != null && _uuidPattern.hasMatch(memberId);

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
