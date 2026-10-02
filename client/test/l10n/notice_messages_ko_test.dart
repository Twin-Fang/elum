import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('보지 않기 문구 — 기본 일수면 일주일간, 아니면 N일간', () {
    expect(noticeHideLabel(NoticeFeed.defaultHideDays), '일주일간 보지 않기');
    expect(noticeHideLabel(3), '3일간 보지 않기');
    expect(ko.noticeHideWeek, '일주일간 보지 않기');
    expect(ko.noticeHideDays(30), '30일간 보지 않기');
  });

  test('링크 실패와 배경 막', () {
    expect(
      ko.noticeLinkOpenFailed('E-NOTICE-LINK'),
      '링크를 열지 못했어요 (E-NOTICE-LINK)',
    );
    expect(ko.noticeCloseBarrier, '공지 닫기');
  });
}
