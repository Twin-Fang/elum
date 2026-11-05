import 'package:flutter/foundation.dart';

/// 요금제가 생긴 경로 — 서버 `SubscriptionSource`
enum SubscriptionSource {
  signup('SIGNUP'),
  manual('MANUAL'),
  appleIap('APPLE_IAP'),
  googleIap('GOOGLE_IAP'),
  promo('PROMO'),

  /// 기존 가입자 Pro 선물 (`expiresAt` = 선물 끝나는 시각)
  proGift('PRO_GIFT'),

  /// 앱이 모르는 새 값
  unknown('');

  const SubscriptionSource(this.apiValue);

  final String apiValue;

  static SubscriptionSource fromApiValue(Object? raw) {
    for (final source in values) {
      if (source != unknown && source.apiValue == raw) return source;
    }
    return unknown;
  }
}

/// 내 요금제 표시용 구독 상태 — 서버 `MemberSubscriptionStatus` (`/api/member/me` · 결제 확인 응답의 `subscription`)
///
/// Pro 여부 판정은 이 값이 아니라 `entitlements.plan`(PlanAccess) 한 곳이 한다. 여기는 만료일·갱신·유예 표시만.
@immutable
class MemberSubscription {
  const MemberSubscription({
    required this.isPro,
    this.source = SubscriptionSource.unknown,
    this.productId,
    this.expiresAt,
    this.willAutoRenew,
    this.isInGracePeriod = false,
  });

  final bool isPro;
  final SubscriptionSource source;

  /// 스토어 상품 id. 스토어 결제가 아니면 null
  final String? productId;

  /// Pro 가 끝나는 시각 (서버 KST, 결제 유예 포함). 기간 제한이 없으면 null
  final DateTime? expiresAt;

  /// 다음 결제일에 자동 갱신되는가. 모르면 null
  final bool? willAutoRenew;

  /// 결제가 실패해 스토어 유예 기간 중인가 (결제 수단 확인 안내)
  final bool isInGracePeriod;

  /// 앱 스토어·구글 플레이로 산 구독인가 (구독 관리 화면이 스토어에 있음)
  bool get isStorePurchase =>
      source == SubscriptionSource.appleIap ||
      source == SubscriptionSource.googleIap;

  /// 서버 응답 한 조각 > 상태. 모양이 다르면 null (화면은 등급만으로 표시)
  static MemberSubscription? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final autoRenew = raw['willAutoRenew'];
    return MemberSubscription(
      isPro: raw['plan'] == 'PRO',
      source: SubscriptionSource.fromApiValue(raw['source']),
      productId: raw['productId'] is String ? raw['productId'] as String : null,
      expiresAt: DateTime.tryParse(raw['expiresAt']?.toString() ?? ''),
      willAutoRenew: autoRenew is bool ? autoRenew : null,
      isInGracePeriod: raw['isInGracePeriod'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MemberSubscription &&
      other.isPro == isPro &&
      other.source == source &&
      other.productId == productId &&
      other.expiresAt == expiresAt &&
      other.willAutoRenew == willAutoRenew &&
      other.isInGracePeriod == isInGracePeriod;

  @override
  int get hashCode => Object.hash(
    isPro,
    source,
    productId,
    expiresAt,
    willAutoRenew,
    isInGracePeriod,
  );
}
