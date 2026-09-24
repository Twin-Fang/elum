import 'package:flutter/foundation.dart';

/// AI 일과 생성 한 번이 쓴 크레딧 — 서버 `RoutineResponse.credit` (#407).
///
/// 크레딧이 꺼져 있으면 서버가 null 을 준다. 그때는 카드 확인의 사용량 줄을
/// 그리지 않는다. 일과 모델([Routine])에 실려 오지만 **생성 응답에만 있다** —
/// 조회·수정 응답에는 없으므로 흐름 상태가 따로 들고 있는다.
@immutable
class CreditUsage {
  const CreditUsage({
    required this.cardCount,
    required this.imageCount,
    required this.charged,
    required this.balanceAfter,
  });

  final int cardCount;

  /// 실제로 붙은 AI 그림 수.
  final int imageCount;

  /// 이번 생성으로 줄어든 크레딧. 잔액이 모자라면 청구보다 작다(초과분은 서버 기록).
  final int charged;

  /// 차감 뒤 남은 크레딧.
  final int balanceAfter;

  /// 네 값이 다 정수로 와야 읽는다. 하나라도 빠지면 null — 틀린 숫자를 그리느니
  /// 줄을 빼는 편이 낫다.
  static CreditUsage? tryParse(Object? raw) {
    if (raw is! Map) return null;
    int? pick(String key) => switch (raw[key]) {
      final int v => v,
      final num v when v == v.roundToDouble() => v.toInt(),
      _ => null,
    };
    final cardCount = pick('cardCount');
    final imageCount = pick('imageCount');
    final charged = pick('charged');
    final balanceAfter = pick('balanceAfter');
    if (cardCount == null ||
        imageCount == null ||
        charged == null ||
        balanceAfter == null) {
      return null;
    }
    return CreditUsage(
      cardCount: cardCount,
      imageCount: imageCount,
      charged: charged,
      balanceAfter: balanceAfter,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CreditUsage &&
      other.cardCount == cardCount &&
      other.imageCount == imageCount &&
      other.charged == charged &&
      other.balanceAfter == balanceAfter;

  @override
  int get hashCode => Object.hash(cardCount, imageCount, charged, balanceAfter);

  @override
  String toString() =>
      'CreditUsage(cards: $cardCount, images: $imageCount, charged: $charged, '
      'balanceAfter: $balanceAfter)';
}
