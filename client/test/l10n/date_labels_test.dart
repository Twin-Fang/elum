import 'package:elum/core/l10n/date_labels.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';

/// 날짜 라벨은 ARB 로 옮겨도 `ko` 결과가 옛 직접 조립과 글자 하나까지 같아야 한다.
/// 기대값은 (1) 옛 조립 코드가 만든 값 (2) 손으로 쓴 문자열 — 새 헬퍼로 만들지 않는다.
void main() {
  useFigmaViewport();
  final ko = lookupAppLocalizations(const Locale('ko'));

  // 한 자리/두 자리 월·일, 연말·연초, 윤년 2/29, 7개 요일, 0·12·23시, 분 0/있음

  test('요일 7개를 월~일 한 글자로 — 손으로 쓴 값', () {
    // 2026-09-28 월 ~ 2026-10-04 일
    const expected = ['월', '화', '수', '목', '금', '토', '일'];
    for (var i = 0; i < 7; i++) {
      expect(ko.weekdayShortOf(DateTime(2026, 9, 28 + i)), expected[i], reason: 'i=$i');
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

}
