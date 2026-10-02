import 'package:elum/core/l10n/date_labels.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 날짜 라벨은 ARB 로 옮겨도 `ko` 결과가 옛 직접 조립과 글자 하나까지 같아야 한다.
/// 기대값은 (1) 옛 조립 코드가 만든 값 (2) 손으로 쓴 문자열 — 새 헬퍼로 만들지 않는다.
void main() {
  useFigmaViewport();
  final ko = lookupAppLocalizations(const Locale('ko'));

  // 한 자리/두 자리 월·일, 연말·연초, 윤년 2/29, 7개 요일, 0·12·23시, 분 0/있음
  final dates = <DateTime>[
    DateTime(2026, 1, 1), // 연초, 목
    DateTime(2026, 9, 5, 9, 5), // 한 자리 월·일
    DateTime(2026, 9, 28), // 월 0시
    DateTime(2026, 9, 29, 3, 30), // 화
    DateTime(2026, 9, 30, 12), // 수 12시
    DateTime(2026, 10, 1, 12, 1), // 목
    DateTime(2026, 10, 2, 23, 59), // 금 23시
    DateTime(2026, 10, 3, 0, 1), // 토
    DateTime(2026, 10, 4, 13, 7), // 일 오후
    DateTime(2026, 12, 31, 23, 0), // 연말
    DateTime(2027, 1, 1, 0, 0),
    DateTime(2028, 2, 29, 6, 15), // 윤년
    DateTime(2026, 11, 11, 11, 11), // 두 자리
  ];

  test('요일 7개를 월~일 한 글자로 — 손으로 쓴 값', () {
    // 2026-09-28 월 ~ 2026-10-04 일
    const expected = ['월', '화', '수', '목', '금', '토', '일'];
    for (var i = 0; i < 7; i++) {
      expect(ko.weekdayShortOf(DateTime(2026, 9, 28 + i)), expected[i], reason: 'i=$i');
    }
  });

  test('yearMonthDay 는 Routine.scheduledDateLabel 과 같다', () {
    for (final d in dates) {
      final old = Routine(id: 'r', scheduledAt: d).scheduledDateLabel;
      expect(ko.yearMonthDay(d), old, reason: '$d');
    }
    expect(ko.yearMonthDay(DateTime(2026, 9, 20)), '2026년 9월 20일');
    expect(ko.yearMonthDay(DateTime(2026, 12, 1)), '2026년 12월 1일');
    expect(ko.yearMonthDay(DateTime(2028, 2, 29)), '2028년 2월 29일');
    expect(ko.yearMonthDay(DateTime(2027, 1, 1)), '2027년 1월 1일');
  });

  test('monthDaySince 는 LinkedDevice.sinceLabel 과 같다', () {
    for (final d in dates) {
      final old = LinkedDevice(linkId: 'x', linkedAt: d).sinceLabel;
      expect(ko.monthDaySince(d), old, reason: '$d');
    }
    expect(ko.monthDaySince(DateTime(2026, 9, 18)), '9월 18일부터');
    expect(ko.monthDaySince(DateTime(2026, 1, 5)), '1월 5일부터');
  });

  test('resetAt 은 CreditSummary.resetLabel 과 같다', () {
    for (final d in dates) {
      final old = CreditSummary(enabled: true, nextResetAt: d).resetLabel;
      expect(ko.resetAt(d), old, reason: '$d');
    }
  });

  test('resetAt 손으로 쓴 값 — 분 0 이면 분을 적지 않는다', () {
    expect(ko.resetAt(DateTime(2026, 9, 28)), '9월 28일(월) 0시');
    expect(ko.resetAt(DateTime(2026, 9, 29, 3, 30)), '9월 29일(화) 3시 30분');
    expect(ko.resetAt(DateTime(2026, 9, 30, 12)), '9월 30일(수) 12시');
    expect(ko.resetAt(DateTime(2026, 10, 2, 23, 59)), '10월 2일(금) 23시 59분');
    expect(ko.resetAt(DateTime(2026, 12, 31, 23)), '12월 31일(목) 23시');
    expect(ko.resetAt(DateTime(2028, 2, 29, 6, 15)), '2월 29일(화) 6시 15분');
    expect(ko.resetAt(DateTime(2026, 10, 4, 0, 1)), '10월 4일(일) 0시 1분');
  });

  test('다음 초기화 시각을 모를 때의 문구는 resetLabel 의 대체와 같다', () {
    expect(ko.creditResetFallback, '다음 주 월요일 0시');
    expect(const CreditSummary(enabled: true).resetLabel, ko.creditResetFallback);
  });

  testWidgets('ko 가 아닌 로케일(es)은 ARB 가 비어 ko 문구로 떨어진다', (tester) async {
    late AppLocalizations l10n;
    await pumpWithLocale(
      tester,
      Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SizedBox();
      }),
      locale: const Locale('es'),
    );
    expect(l10n.localeName, 'es');
    // 번역이 채워지면 이 단언은 그 언어 문구로 바뀐다 — 지금은 ko 대체가 계약이다
    expect(l10n.yearMonthDay(DateTime(2026, 9, 20)), '2026년 9월 20일');
    expect(l10n.resetAt(DateTime(2026, 9, 29, 3, 30)), '9월 29일(화) 3시 30분');
    expect(l10n.monthDaySince(DateTime(2026, 9, 18)), '9월 18일부터');
    expect(l10n.weekdayShortOf(DateTime(2026, 10, 4)), '일');
  });
}
