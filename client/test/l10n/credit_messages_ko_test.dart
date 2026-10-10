import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/credit_fixtures.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('홈 막기 팝업', () {
    expect(
      ko.creditBlockedExhausted('9월 28일(월) 0시'),
      '이번 주 크레딧을 모두 사용했어요.\n9월 28일(월) 0시부터 다시 만들 수 있어요',
    );
    expect(
      ko.creditBlockedExhausted('다음 주 월요일 0시'),
      '이번 주 크레딧을 모두 사용했어요.\n다음 주 월요일 0시부터 다시 만들 수 있어요',
    );
    expect(ko.creditAdOffer(1), '광고를 끝까지 보면 크레딧 1개를 받아요');
    expect(ko.creditAdOffer(10), '광고를 끝까지 보면 크레딧 10개를 받아요');
  });

  test('지급 알림', () {
    expect(ko.creditReceivedTitle(5), '크레딧 5개를 받았어요');
    expect(ko.creditReceivedTitle(12), '크레딧 12개를 받았어요');
  });

  test('초기화 시각은 날짜 라벨 헬퍼를 거쳐도 옛 문구와 같다', () {
    expect(CreditSummary.fromJson(creditJson()).resetLabel, '9월 28일(월) 0시');
    // 분이 있으면 분까지, 서버가 시각을 안 주면 대체 문구
    final withMinute = creditJson()..['nextResetAt'] = '2026-09-29T03:30:00';
    expect(CreditSummary.fromJson(withMinute).resetLabel, '9월 29일(화) 3시 30분');
    expect(const CreditSummary(enabled: true).resetLabel, '다음 주 월요일 0시');
  });
}
