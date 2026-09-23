import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/theme/app_typography.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/semantics_audit.dart';

/// 공지 팝업 (이슈 #371 · 명세 2-1 모양 · 3-2 앱).
///
/// 참고 화면(사내 웹 공지 팝업)을 휴대폰에 옮겼다 — 위 큰 그림, 제목 일부 강조,
/// 설명, 가운데 버튼, 맨 아래 점과 ← →, 오른쪽 위 "☐ 보지 않기"와 ✕.
void main() {
  useFigmaViewport();

  const colors = AppColors.light;

  AppNotice notice(
    String id, {
    String? image,
    NoticeButton? button,
    String? title,
    String body = '더 많이 만들 수 있게 준비하고 있어요.',
  }) => AppNotice(
    id: id,
    revision: 1,
    title: title ?? '제목 $id',
    body: body,
    imageUrl: image,
    button: button,
  );

  NoticeFeed feedOf(List<AppNotice> notices, {int hideDays = 7}) =>
      NoticeFeed(hideDays: hideDays, notices: notices);

  final link = NoticeButton(
    label: '자세히 보기',
    url: Uri.parse('https://elum.app/beta'),
  );

  /// 그림은 네트워크를 타지 않는다. 주소가 `broken` 으로 시작하면 실패하는 그림.
  ImageProvider imageFor(String url) => url.startsWith('broken')
      ? const _BrokenImage()
      : MemoryImage(_onePixelPng);

  /// 팝업 본체만 화면 가운데 세운다.
  Future<void> pumpCard(
    WidgetTester tester,
    NoticeFeed feed, {
    ValueNotifier<bool>? hide,
    VoidCallback? onClose,
    NoticeLinkOpener? openLink,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NoticePopupCard(
            feed: feed,
            hideChecked: hide ?? ValueNotifier(false),
            onClose: onClose ?? () {},
            openLink: openLink ?? (_) async => true,
            imageFor: imageFor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 슬라이드 안의 것만 찾는다. 카드 높이를 재려고 슬라이드를 한 벌 더 그려 두기 때문이다.
  Finder inPages(Finder finder) => find.descendant(
    of: find.byKey(NoticePopupCard.pagesKey),
    matching: finder,
  );

  Finder card() => find.byKey(NoticePopupCard.cardKey);

  group('명세 2-1 치수', () {
    testWidgets('카드 폭은 화면의 90%', (tester) async {
      await pumpCard(tester, feedOf([notice('a')]));
      expect(tester.getSize(card()).width, closeTo(393 * 0.9, 0.01));
    });

    testWidgets('넓은 화면에서도 360 을 넘지 않는다', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      await pumpCard(tester, feedOf([notice('a')]));
      expect(tester.getSize(card()).width, 360);
    });

    testWidgets('그림 영역은 16:10 이고 카드 폭을 꽉 채운다', (tester) async {
      await pumpCard(tester, feedOf([notice('a', image: 'img')]));
      final image = tester.getSize(
        inPages(find.byKey(const ValueKey('notice-image-a'))),
      );
      expect(image.width, closeTo(393 * 0.9, 0.01));
      expect(image.height, closeTo(393 * 0.9 * 10 / 16, 0.01));
    });

    test('제목 18 굵게 · 본문 14 · 버튼 16 — 토큰으로 둔다', () {
      const typo = AppTypography.standard;
      expect(typo.noticeTitle.fontSize, 18);
      expect(typo.noticeTitle.fontWeight, FontWeight.w700);
      expect(typo.noticeBody.fontSize, 14);
      expect(typo.noticeAction.fontSize, 16);
      // 설명 최소 14 (docs/08 §7-2) — 체크박스 글자도 설명이다
      expect(typo.noticeHideLabel.fontSize, 14);
    });

    testWidgets('누르는 곳은 전부 44×44 이상이다', (tester) async {
      await pumpCard(tester, feedOf([notice('a', button: link), notice('b')]));
      for (final label in ['공지 닫기', '다음 공지', '일주일간 보지 않기']) {
        final size = tester.getSize(find.bySemanticsLabel(label));
        expect(size.width, greaterThanOrEqualTo(44), reason: label);
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
      }
      expect(
        tester
            .getSize(inPages(find.byKey(const ValueKey('notice-link-a'))))
            .height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  group('N25 제목 강조', () {
    testWidgets('**…** 안쪽만 포인트색으로 칠한다', (tester) async {
      await pumpCard(
        tester,
        feedOf([notice('a', title: '베타 기간에는 **하루 3개**까지 만들 수 있어요')]),
      );
      final spans = _spansOf(
        tester,
        inPages(find.byKey(const ValueKey('notice-title-a'))),
      );
      expect(spans['하루 3개'], colors.checkDone);
      expect(spans['베타 기간에는 '], colors.dialogTitleText);
      expect(spans['까지 만들 수 있어요'], colors.dialogTitleText);
    });

    testWidgets('짝이 안 맞으면 강조 없이 ** 만 지운다', (tester) async {
      await pumpCard(tester, feedOf([notice('a', title: '하루 **3개까지')]));
      final spans = _spansOf(
        tester,
        inPages(find.byKey(const ValueKey('notice-title-a'))),
      );
      expect(spans, {'하루 3개까지': colors.dialogTitleText});
    });
  });

  group('슬라이드', () {
    testWidgets('N23 한 장이면 점과 화살표를 숨긴다', (tester) async {
      await pumpCard(tester, feedOf([notice('a')]));
      expect(find.byKey(NoticePopupCard.dotsKey), findsNothing);
      expect(find.bySemanticsLabel('이전 공지'), findsNothing);
      expect(find.bySemanticsLabel('다음 공지'), findsNothing);
    });

    testWidgets('첫 장에서는 ← 를, 끝 장에서는 → 를 숨긴다', (tester) async {
      await pumpCard(tester, feedOf([notice('a'), notice('b'), notice('c')]));
      expect(find.bySemanticsLabel('이전 공지'), findsNothing);
      expect(find.bySemanticsLabel('다음 공지'), findsOneWidget);
      expect(find.bySemanticsLabel('1/3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('다음 공지'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2/3'), findsOneWidget);
      expect(find.bySemanticsLabel('이전 공지'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('다음 공지'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('3/3'), findsOneWidget);
      expect(find.bySemanticsLabel('다음 공지'), findsNothing);

      await tester.tap(find.bySemanticsLabel('이전 공지'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2/3'), findsOneWidget);
    });

    testWidgets('옆으로 밀어서도 넘긴다', (tester) async {
      await pumpCard(tester, feedOf([notice('a'), notice('b')]));
      await tester.drag(inPages(find.text('제목 a')), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('2/2'), findsOneWidget);
    });

    testWidgets('넘기면 위치를 소리로 읽어 준다 — "2/3"', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              announced.add(
                (map['data'] as Map<Object?, Object?>)['message'] as String,
              );
            }
            return null;
          });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );

      await pumpCard(tester, feedOf([notice('a'), notice('b'), notice('c')]));
      await tester.tap(find.bySemanticsLabel('다음 공지'));
      await tester.pumpAndSettle();

      expect(announced, ['2/3']);
    });

    testWidgets('N28 그림이 섞이면 모든 장에 같은 높이의 그림 자리를 두고 빈 장은 연한 배경으로 채운다', (
      tester,
    ) async {
      await pumpCard(tester, feedOf([notice('a', image: 'img'), notice('b')]));
      final withImage = tester.getSize(
        inPages(find.byKey(const ValueKey('notice-image-a'))),
      );
      final cardHeight = tester.getSize(card()).height;

      await tester.tap(find.bySemanticsLabel('다음 공지'));
      await tester.pumpAndSettle();

      final empty = inPages(find.byKey(const ValueKey('notice-image-empty-b')));
      expect(empty, findsOneWidget);
      expect(tester.getSize(empty), withImage);
      expect(_colorOf(tester, empty), colors.noticeImagePlaceholder);
      // 카드 높이가 장마다 튀지 않는다
      expect(tester.getSize(card()).height, cardHeight);
    });

    testWidgets('그림이 하나도 없으면 그림 자리를 두지 않는다', (tester) async {
      await pumpCard(tester, feedOf([notice('a'), notice('b')]));
      expect(find.byKey(const ValueKey('notice-image-empty-a')), findsNothing);
      expect(find.byKey(const ValueKey('notice-image-a')), findsNothing);
      // 그림이 없어도 닫기와 보지 않기는 있다
      expect(find.bySemanticsLabel('공지 닫기'), findsOneWidget);
      expect(find.bySemanticsLabel('일주일간 보지 않기'), findsOneWidget);
    });

    testWidgets('카드는 가장 긴 장에 맞춘다 — 짧은 공지로 화면을 채우지 않는다', (tester) async {
      // "장마다 높이가 같다"만 보면 카드를 최대 높이로 늘려도 통과한다. 그래서 따로 본다.
      await pumpCard(tester, feedOf([notice('a'), notice('b')]));
      expect(tester.getSize(card()).height, lessThan(852 * 0.4));
    });

    testWidgets('글이 짧은 장과 긴 장이 섞여도 카드 높이가 그대로다', (tester) async {
      await pumpCard(
        tester,
        feedOf([notice('a'), notice('b', body: '줄이 많은 본문\n' * 6)]),
      );
      final first = tester.getSize(card()).height;
      await tester.tap(find.bySemanticsLabel('다음 공지'));
      await tester.pumpAndSettle();
      expect(tester.getSize(card()).height, first);
    });
  });

  group('N3 그림을 못 불러오면', () {
    testWidgets('그림 자리를 없애고 글만 보인다 — 빈 칸 금지', (tester) async {
      await pumpCard(tester, feedOf([notice('a', image: 'broken-a')]));
      expect(find.byKey(const ValueKey('notice-image-a')), findsNothing);
      expect(find.byKey(const ValueKey('notice-image-empty-a')), findsNothing);
      expect(inPages(find.text('제목 a')), findsOneWidget);
      expect(find.bySemanticsLabel('공지 닫기'), findsOneWidget);
    });

    testWidgets('다른 장에 그림이 남아 있으면 그 장만 연한 배경이 된다', (tester) async {
      await pumpCard(
        tester,
        feedOf([notice('a', image: 'img'), notice('b', image: 'broken-b')]),
      );
      await tester.tap(find.bySemanticsLabel('다음 공지'));
      await tester.pumpAndSettle();
      expect(
        inPages(find.byKey(const ValueKey('notice-image-empty-b'))),
        findsOneWidget,
      );
    });
  });

  group('N4 본문이 길다', () {
    testWidgets('작은 화면·글꼴 2.0 에서도 본문만 스크롤되고 누를 것은 전부 보인다', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      Uri? opened;
      await pumpCard(
        tester,
        feedOf([
          notice('a', image: 'img', button: link, body: '가' * 1000),
          notice('b'),
        ]),
        openLink: (uri) async {
          opened = uri;
          return true;
        },
      );
      // 여기까지 왔으면 오버플로가 없다 (flutter_test_config 가 오버플로를 실패로 만든다)

      const screen = Rect.fromLTWH(0, 0, 360, 640);
      for (final target in [
        find.bySemanticsLabel('공지 닫기'),
        find.bySemanticsLabel('다음 공지'),
        find.bySemanticsLabel('일주일간 보지 않기'),
        inPages(find.byKey(const ValueKey('notice-link-a'))),
      ]) {
        final rect = tester.getRect(target);
        expect(
          screen.contains(rect.topLeft) &&
              screen.contains(rect.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: '$target 가 화면 밖이다: $rect',
        );
      }

      // 본문을 밀어도 버튼은 제자리다
      final buttonBefore = tester.getRect(
        inPages(find.byKey(const ValueKey('notice-link-a'))),
      );
      final body = inPages(find.byKey(const ValueKey('notice-body-a')));
      final bodyTop = tester.getTopLeft(body).dy;
      // 본문 한가운데는 1000자라 글 자리 밖에 있다 — 글 자리를 잡고 민다
      await tester.drag(
        inPages(find.byKey(const ValueKey('notice-scroll-a'))),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(body).dy,
        lessThan(bodyTop),
        reason: '본문이 스크롤되지 않았다',
      );
      expect(
        tester.getRect(inPages(find.byKey(const ValueKey('notice-link-a')))),
        buttonBefore,
      );

      await tester.tap(inPages(find.byKey(const ValueKey('notice-link-a'))));
      await tester.pumpAndSettle();
      expect(opened, link.url);
    });

    for (final scale in [2.0, 3.0]) {
      testWidgets('글꼴 $scale · 360 폭에서도 "일주일간 보지 않기"가 잘리지 않는다', (tester) async {
        // 3배 안팎(iOS 손쉬운 사용)에서는 ✕ 와 한 줄에 못 들어가 "일주일간 보…"로
        // 잘린다 — 무엇을 체크하는지 읽을 수 없다. 조작부만 2배에서 멈춘다.
        tester.view.physicalSize = const Size(360, 640);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpCard(tester, feedOf([notice('a', image: 'img')]));

        final label = tester.renderObject<RenderParagraph>(
          find.text('일주일간 보지 않기'),
        );
        expect(label.didExceedMaxLines, isFalse);
        // 멈추는 곳이 2배보다 낮으면 2배를 쓰는 보호자의 글자까지 괜히 작아진다
        expect(label.textScaler.scale(14), 28);
      });
    }

    testWidgets('본문 자리는 화면 높이의 45% 를 넘지 않는다', (tester) async {
      await pumpCard(tester, feedOf([notice('a', body: '가나다라 ' * 400)]));
      final region = inPages(find.byKey(const ValueKey('notice-scroll-a')));
      expect(
        tester.getSize(region).height,
        lessThanOrEqualTo(852 * 0.45 + 0.01),
      );
    });
  });

  group('보지 않기 · 닫기', () {
    testWidgets('일수가 7 이 아니면 "N일간 보지 않기"', (tester) async {
      await pumpCard(tester, feedOf([notice('a')], hideDays: 3));
      expect(find.bySemanticsLabel('3일간 보지 않기'), findsOneWidget);
    });

    testWidgets('체크박스는 상태까지 읽히고 글자까지 눌린다', (tester) async {
      final hide = ValueNotifier(false);
      await pumpCard(tester, feedOf([notice('a')]), hide: hide);

      final toggle = find.bySemanticsLabel('일주일간 보지 않기');
      expect(
        tester.getSemantics(toggle),
        containsSemantics(
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );

      // 네모가 아니라 글자를 눌러도 켜진다
      await tester.tap(find.text('일주일간 보지 않기'));
      await tester.pumpAndSettle();
      expect(hide.value, isTrue);
      expect(tester.getSemantics(toggle), containsSemantics(isChecked: true));

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(hide.value, isFalse);
    });

    testWidgets('✕ 를 누르면 닫는다', (tester) async {
      var closed = 0;
      await pumpCard(tester, feedOf([notice('a')]), onClose: () => closed++);
      await tester.tap(find.bySemanticsLabel('공지 닫기'));
      expect(closed, 1);
    });
  });

  group('showNoticePopup — 닫힌 뒤 보지 않기 여부를 돌려준다', () {
    Future<Future<bool>> open(WidgetTester tester, NoticeFeed feed) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      final result = showNoticePopup(ctx, feed, imageFor: imageFor);
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('체크하지 않고 ✕ — 이번 실행에서만 닫는다', (tester) async {
      final result = await open(tester, feedOf([notice('a')]));
      await tester.tap(find.bySemanticsLabel('공지 닫기'));
      await tester.pumpAndSettle();
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
      expect(await result, isFalse);
    });

    testWidgets('체크하고 ✕ — 숨긴다', (tester) async {
      final result = await open(tester, feedOf([notice('a')]));
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.tap(find.bySemanticsLabel('공지 닫기'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('바깥(어두운 배경)을 눌러도 닫힌다 — 체크돼 있으면 숨긴다', (tester) async {
      final result = await open(tester, feedOf([notice('a')]));
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
      expect(await result, isTrue);
    });

    testWidgets('안드로이드 뒤로가기로 닫아도 같다', (tester) async {
      final result = await open(tester, feedOf([notice('a')]));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(NoticePopupCard.cardKey), findsNothing);
      expect(await result, isFalse);
    });
  });

  group('링크 버튼', () {
    testWidgets('버튼이 없으면 자리를 두지 않는다', (tester) async {
      await pumpCard(tester, feedOf([notice('a')]));
      expect(find.byKey(const ValueKey('notice-link-a')), findsNothing);
    });

    testWidgets('누르면 링크를 연다', (tester) async {
      final opened = <Uri>[];
      await pumpCard(
        tester,
        feedOf([notice('a', button: link)]),
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await tester.tap(inPages(find.text('자세히 보기')));
      await tester.pumpAndSettle();
      expect(opened, [link.url]);
    });

    testWidgets('열지 못하면 에러 코드와 함께 알린다 — 팝업은 그대로', (tester) async {
      await pumpCard(
        tester,
        feedOf([notice('a', button: link)]),
        openLink: (_) async => false,
      );
      await tester.tap(inPages(find.text('자세히 보기')));
      await tester.pumpAndSettle();
      expect(inPages(find.textContaining('E-NOTICE-LINK')), findsOneWidget);
      expect(card(), findsOneWidget);
    });

    test('https 가 아닌 주소는 열지 않는다 (N12 두 번째 거름)', () async {
      expect(await openNoticeLink(Uri.parse('http://x.test')), isFalse);
      expect(await openNoticeLink(Uri.parse('intent://x')), isFalse);
    });
  });

  testWidgets('접근성 — 누를 수 있는 것은 전부 이름이 있다', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCard(
      tester,
      feedOf([notice('a', image: 'img', button: link), notice('b')]),
    );

    expectLabeledButton(tester, '공지 닫기');
    expectLabeledButton(tester, '다음 공지');
    expect(unnamedTapTargets(tester), isEmpty);

    await tester.tap(find.bySemanticsLabel('다음 공지'));
    await tester.pumpAndSettle();
    expectLabeledButton(tester, '이전 공지');
    handle.dispose();
  });
}

/// RichText 의 글 조각별 색. 조각 글자 → 색.
Map<String, Color?> _spansOf(WidgetTester tester, Finder finder) {
  final rich = tester.widget<RichText>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  final out = <String, Color?>{};
  final base = rich.text.style?.color;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
      out[span.text!] = span.style?.color ?? base;
    }
    return true;
  });
  return out;
}

Color? _colorOf(WidgetTester tester, Finder finder) {
  final box = tester.widget<ColoredBox>(
    find
        .descendant(
          of: finder,
          matching: find.byType(ColoredBox),
          matchRoot: true,
        )
        .first,
  );
  return box.color;
}

/// 1×1 투명 PNG — 네트워크 없이 "그림이 있다"를 흉내 낸다.
final _onePixelPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0B,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x60,
  0x00,
  0x02,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x7A,
  0x5E,
  0xAB,
  0x3F,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

/// 불러오다 실패하는 그림 — 서버가 404 를 준 상황.
class _BrokenImage extends ImageProvider<_BrokenImage> {
  const _BrokenImage();

  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _BrokenImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(StateError('404 — 그림이 없다')),
  );
}
