import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 크레딧 카드가 끝까지 보여 준 잔액 (남은 수 · 막대 비율)
@immutable
class CreditShownValue {
  const CreditShownValue({required this.available, required this.ratio});

  /// 아직 본 적 없음 > 0 에서 채움
  static const empty = CreditShownValue(available: 0, ratio: 0);

  final int available;
  final double ratio;

  @override
  bool operator ==(Object other) =>
      other is CreditShownValue &&
      other.available == available &&
      other.ratio == ratio;

  @override
  int get hashCode => Object.hash(available, ratio);
}

/// 마지막으로 보여 준 잔액: 다음에 카드가 뜰 때 이 값 > 새 값으로 움직임 (앱 실행 동안만, 기기 저장 안 함)
class CreditLastShownNotifier extends Notifier<CreditShownValue?> {
  @override
  CreditShownValue? build() => null;

  void remember(CreditShownValue value) => state = value;
}

final creditLastShownProvider =
    NotifierProvider<CreditLastShownNotifier, CreditShownValue?>(
      CreditLastShownNotifier.new,
    );
