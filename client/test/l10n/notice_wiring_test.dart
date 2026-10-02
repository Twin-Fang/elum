import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/pump_with_locale.dart';

/// 공지 팝업이 앱 문구를 ARB 에서 읽는지 정확한 문자열로 확인한다.
void main() {
  useFigmaViewport();
  // 비 ko 로 띄운 테스트가 전역 `appL10n` 을 남기지 않게 되돌린다
  tearDown(setAppL10nForTest);

  final plain = AppNotice(id: 'n', revision: 1, title: '제목', body: '본문');
  final withLink = AppNotice(
    id: 'n',
    revision: 1,
    title: '제목',
    body: '본문',
    button: NoticeButton(label: '보기', url: Uri.parse('https://example.com')),
  );

  Widget card(AppNotice n, {int hideDays = 7, NoticeLinkOpener? openLink}) =>
      Scaffold(
        body: NoticePopupCard(
          notice: n,
          hideDays: hideDays,
          hideChecked: ValueNotifier(false),
          onClose: () {},
          onLinkOpened: () {},
          openLink: openLink ?? (_) async => true,
          imageFor: (_) => throw UnimplementedError(),
        ),
      );

  testWidgets('보지 않기 문구 — 기본 일수와 그 밖의 일수(값 3개)', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithLocale(tester, card(plain));
    expect(find.bySemanticsLabel('일주일간 보지 않기'), findsOneWidget);
    await pumpWithLocale(tester, card(plain, hideDays: 3));
    expect(find.bySemanticsLabel('3일간 보지 않기'), findsOneWidget);
    await pumpWithLocale(tester, card(plain, hideDays: 30));
    expect(find.bySemanticsLabel('30일간 보지 않기'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('링크 실패 문구는 에러 코드까지 정확히, 닫기 버튼은 닫기', (tester) async {
    await pumpWithLocale(tester, card(plain));
    expect(find.text('닫기'), findsOneWidget);
    await pumpWithLocale(tester, card(withLink, openLink: (_) async => false));
    await tester.tap(find.byKey(const ValueKey('notice-link-n')));
    await tester.pumpAndSettle();
    expect(find.text('링크를 열지 못했어요 (E-NOTICE-LINK)'), findsOneWidget);
  });

  testWidgets('배경 막 이름이 공지 닫기', (tester) async {
    final handle = tester.ensureSemantics();
    late BuildContext ctx;
    await pumpWithLocale(
      tester,
      Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    );
    showNoticePopup(
      ctx,
      plain,
      hideDays: 7,
      imageFor: (_) => throw UnimplementedError(),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('공지 닫기'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('번역이 없는 언어는 한국어 문구로 떨어진다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpWithLocale(
      tester,
      card(plain, hideDays: 3),
      locale: const Locale('en'),
    );
    expect(find.bySemanticsLabel('3일간 보지 않기'), findsOneWidget);
    expect(find.text('닫기'), findsOneWidget);
    handle.dispose();
  });
}
