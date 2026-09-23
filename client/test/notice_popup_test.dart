import 'package:elum/core/text/keep_words.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/theme/app_typography.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:elum/features/notice/presentation/widgets/notice_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/semantics_audit.dart';

/// 공지 팝업 (이슈 #390 · 시안 `팝업` 931:4878 의 `방침` 변형 1090:4922).
///
/// 공지가 앱의 다른 팝업(로그아웃·회원탈퇴·일과 삭제)과 **같은 컴포넌트**가 됐다.
/// 오른쪽 위 ✕ · 위쪽 체크박스 · 슬라이드·점·화살표(#371)는 없다.
void main() {
  useFigmaViewport();

  const colors = AppColors.light;
  const wj = '\u2060';

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

  final policy = NoticeButton(
    label: '방침 보기',
    url: Uri.parse('https://twin-fang.github.io/elum/privacy.html'),
  );

  /// 시안(1090:4922)이 그린 글 그대로. 제목·본문 모두 두 줄이다.
  AppNotice designNotice({NoticeButton? button, String? image}) => AppNotice(
    id: 'design',
    revision: 2,
    title: '개인정보처리방침이 \n**9월 30일**에 바뀌어요',
    body: '카드 그림을 만드는 업체가 하나 늘어요.\n자세한 내용은 방침에서 확인할 수 있어요',
    button: button,
    imageUrl: image,
  );

  /// 그림은 네트워크를 타지 않는다. 주소가 `broken` 으로 시작하면 실패하는 그림.
  ImageProvider imageFor(String url) => url.startsWith('broken')
      ? const _BrokenImage()
      : MemoryImage(_onePixelPng);

  /// 팝업 본체만 화면 가운데 세운다. 공통 팝업처럼 `.w`·`.h` 를 쓰므로 ScreenUtil 아래에 둔다.
  Future<void> pumpCard(
    WidgetTester tester,
    AppNotice n, {
    int hideDays = 7,
    ValueNotifier<bool>? hide,
    VoidCallback? onClose,
    VoidCallback? onLinkOpened,
    NoticeLinkOpener? openLink,
  }) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: NoticePopupCard(
              notice: n,
              hideDays: hideDays,
              hideChecked: hide ?? ValueNotifier(false),
              onClose: onClose ?? () {},
              onLinkOpened: onLinkOpened ?? () {},
              openLink: openLink ?? (_) async => true,
              imageFor: imageFor,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder card() => find.byKey(NoticePopupCard.cardKey);
  Finder closeButton() => find.byKey(NoticePopupCard.closeKey);
  Finder linkButton(String id) => find.byKey(ValueKey('notice-link-$id'));
  Finder titleOf(String id) => find.byKey(ValueKey('notice-title-$id'));
  Finder bodyOf(String id) => find.byKey(ValueKey('notice-body-$id'));

  /// 버튼의 색 면(DecoratedBox)
  BoxDecoration buttonFace(WidgetTester tester, Finder button) =>
      tester
              .widget<DecoratedBox>(
                find
                    .descendant(of: button, matching: find.byType(DecoratedBox))
                    .first,
              )
              .decoration
          as BoxDecoration;

  group('시안 1090:4922 치수 — 공통 팝업과 같다', () {
    testWidgets('카드 322 · 높이 244 (시안 글 그대로)', (tester) async {
      await pumpCard(tester, designNotice(button: policy));
      expect(tester.getSize(card()), const Size(322, 244));
      // 화면 한가운데 — 공통 팝업처럼 안전영역이 아니라 화면 전체 기준 (#297)
      expect(tester.getCenter(card()), const Offset(393 / 2, 852 / 2));
    });

    testWidgets('보이는 간격 — 제목↔본문 20 · 본문↔보지 않기 24 · 보지 않기↔버튼 14', (
      tester,
    ) async {
      await pumpCard(tester, designNotice(button: policy));
      final top = tester.getTopLeft(card()).dy;
      final title = tester.getRect(titleOf('design'));
      final body = tester.getRect(bodyOf('design'));
      final check = tester.getRect(find.byType(NoticeRoundCheck));
      final buttons = tester.getRect(closeButton());

      expect(title.top - top, 24, reason: '위 여백');
      expect(body.top - title.bottom, closeTo(20, 0.5));
      expect(check.top - body.bottom, closeTo(24, 0.5));
      expect(check.size, const Size(16, 16));
      expect(buttons.top - check.bottom, closeTo(14, 0.5));
      expect(tester.getBottomLeft(card()).dy - buttons.bottom, 14);
    });

    testWidgets('버튼 145 × 54 둘, 사이 4 — 로그아웃 팝업과 같다', (tester) async {
      await pumpCard(tester, designNotice(button: policy));
      final close = tester.getRect(closeButton());
      final link = tester.getRect(linkButton('design'));
      expect(close.size, const Size(145, 54));
      expect(link.size, const Size(145, 54));
      expect(link.left - close.right, 4);
    });

    test('글자 — 제목 18/500 · 본문 16/400 · 보지 않기 14/400 · 버튼은 공통 팝업 것', () {
      const typo = AppTypography.standard;
      expect(typo.noticeTitle.fontSize, 18);
      expect(typo.noticeTitle.fontWeight, FontWeight.w500);
      expect(typo.noticeTitle.height, 1.1); // 시안 줄 19.8
      expect(typo.noticeBody.fontSize, 16);
      expect(typo.noticeBody.fontWeight, FontWeight.w400);
      expect(typo.noticeBody.height, 1.2); // 시안 줄 19.2
      expect(typo.noticeHideLabel.fontSize, 14);
      expect(typo.noticeHideLabel.fontWeight, FontWeight.w400);
      expect(colors.noticeHideLabel, const Color(0xFF74757D));
    });

    testWidgets('오른쪽 위 ✕ · 점 · 화살표가 없다 (#371 의 웹 공지 모양)', (tester) async {
      await pumpCard(tester, designNotice(button: policy));
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.byType(PageView), findsNothing);
      expect(find.bySemanticsLabel('다음 공지'), findsNothing);
    });
  });

  group('버튼 — R1 · R2', () {
    testWidgets('R1 링크가 없으면 닫기 하나를 꽉 채우고 주 동작 색이다', (tester) async {
      await pumpCard(tester, designNotice());
      expect(linkButton('design'), findsNothing);
      expect(tester.getSize(closeButton()), const Size(294, 54));
      // 공통 팝업 info 변형처럼 혼자 선 버튼은 민트 — 회색이 혼자 서면 꺼진 버튼으로 읽힌다
      expect(buttonFace(tester, closeButton()).color, colors.checkDone);
    });

    testWidgets('링크가 있으면 닫기(회색) · 링크(민트)', (tester) async {
      await pumpCard(tester, designNotice(button: policy));
      expect(buttonFace(tester, closeButton()).color, colors.dialogNeutral);
      expect(buttonFace(tester, linkButton('design')).color, colors.checkDone);
    });

    testWidgets('R2 버튼 문구가 길면 말줄임 없이 어절에서 꺾고 두 버튼 크기가 같다', (tester) async {
      await pumpCard(
        tester,
        notice(
          'a',
          button: NoticeButton(
            label: '베타 한도 자세히 보기',
            url: Uri.parse('https://elum.app/beta'),
          ),
        ),
      );
      final close = tester.getRect(closeButton());
      final link = tester.getRect(linkButton('a'));
      expect(close.size, link.size, reason: '한쪽만 키가 커지면 줄이 들쭉날쭉하다');
      // 두 줄(18×2)도 버튼 최소 높이 54 안에 들어간다 — 한 줄 버튼과 키가 같다
      expect(link.height, 54);

      final label = tester.renderObject<RenderParagraph>(
        find.descendant(of: linkButton('a'), matching: find.byType(RichText)),
      );
      expect(label.didExceedMaxLines, isFalse);
      expect(label.text.toPlainText(), keepWords('베타 한도 자세히 보기'));
      expect(
        label.getMaxIntrinsicWidth(double.infinity),
        greaterThan(link.width),
        reason: '한 줄로는 안 들어가는 문구라야 이 테스트가 뜻이 있다',
      );
      // 어절에서 꺾였다 — 둘째 줄이 어절 첫 글자로 시작한다
      final painter = TextPainter(
        text: label.text,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: label.size.width);
      addTearDown(painter.dispose);
      final first = painter.getLineBoundary(const TextPosition(offset: 0));
      final firstLine = label.text
          .toPlainText()
          .substring(0, first.end)
          .replaceAll(wj, '')
          .trim();
      expect('베타 한도 자세히 보기'.split(' '), containsAll(firstLine.split(' ')));
    });

    testWidgets('링크를 누르면 연 뒤 닫힌다 — 공통 팝업처럼 버튼은 팝업을 닫는다', (tester) async {
      final opened = <Uri>[];
      var linked = 0;
      await pumpCard(
        tester,
        designNotice(button: policy),
        openLink: (uri) async {
          opened.add(uri);
          return true;
        },
        onLinkOpened: () => linked++,
      );
      await tester.tap(linkButton('design'));
      await tester.pumpAndSettle();
      expect(opened, [policy.url]);
      expect(linked, 1);
    });

    testWidgets('링크를 열지 못하면 에러 코드와 함께 알리고 닫지 않는다', (tester) async {
      var linked = 0;
      await pumpCard(
        tester,
        designNotice(button: policy),
        openLink: (_) async => false,
        onLinkOpened: () => linked++,
      );
      await tester.tap(linkButton('design'));
      await tester.pumpAndSettle();
      expect(find.textContaining('E-NOTICE-LINK'), findsOneWidget);
      expect(linked, 0);
      expect(card(), findsOneWidget);
    });

    testWidgets('닫기를 누르면 닫는다', (tester) async {
      var closed = 0;
      await pumpCard(tester, designNotice(), onClose: () => closed++);
      await tester.tap(closeButton());
      expect(closed, 1);
    });

    test('https 가 아닌 주소는 열지 않는다 (N12 두 번째 거름)', () async {
      expect(await openNoticeLink(Uri.parse('http://x.test')), isFalse);
      expect(await openNoticeLink(Uri.parse('intent://x')), isFalse);
    });
  });

  group('N25 제목 강조', () {
    testWidgets('**…** 안쪽만 포인트색으로 칠한다', (tester) async {
      await pumpCard(tester, designNotice());
      final spans = _spansOf(tester, titleOf('design'));
      expect(spans['9월 30일'], colors.checkDone);
      expect(spans['개인정보처리방침이 \n'], colors.dialogTitleText);
      expect(spans['에 바뀌어요'], colors.dialogTitleText);
    });

    testWidgets('짝이 안 맞으면 강조 없이 ** 만 지운다', (tester) async {
      await pumpCard(tester, notice('a', title: '하루 **3개까지'));
      expect(_spansOf(tester, titleOf('a')), {
        '하루 3개까지': colors.dialogTitleText,
      });
    });
  });

  group('#385 A 어절 단위 줄바꿈 — 관리자 미리보기와 같은 규칙', () {
    const body = '카드 그림을 만드는 업체가 하나 늘어요. 자세한 내용은 방침에서 확인할 수 있어요.';

    testWidgets('제목·본문에 끊지 말라는 표시가 들어가고 낭독기는 원문을 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(
        tester,
        notice('a', title: '방침이 **9월 30일**에 바뀌어요', body: body),
      );

      final bodyText = tester.widget<Text>(bodyOf('a'));
      expect(bodyText.data, keepWords(body));
      expect(find.bySemanticsLabel(body), findsOneWidget);
      expect(find.bySemanticsLabel('방침이 9월 30일에 바뀌어요'), findsOneWidget);
      // 강조 조각 경계("일"|"에")에도 표시가 있다 — 없으면 "30일 / 에"로 끊긴다
      final spans = _spansOf(tester, titleOf('a'), raw: true).keys.toList();
      expect(spans.last.startsWith(wj), isTrue);
      handle.dispose();
    });

    testWidgets('운영 공지가 카드 폭에서 어절 가운데로 끊기지 않는다 — "방 / 침에서" 재발 방지', (
      tester,
    ) async {
      await pumpCard(tester, notice('a', body: body));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: bodyOf('a'), matching: find.byType(RichText)),
      );
      final words = body.split(' ');
      final text = paragraph.text.toPlainText();
      // 화면에 그린 것과 같은 글·폭으로 다시 재서 줄을 나눈다
      final painter = TextPainter(
        text: paragraph.text,
        textAlign: paragraph.textAlign,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.constraints.maxWidth);
      addTearDown(painter.dispose);
      var offset = 0;
      final lines = <String>[];
      while (offset < text.length) {
        final range = painter.getLineBoundary(TextPosition(offset: offset));
        if (range.end <= offset) {
          offset++;
          continue;
        }
        lines.add(text.substring(offset, range.end).replaceAll(wj, '').trim());
        offset = range.end;
      }
      expect(lines.length, greaterThan(1));
      for (final line in lines) {
        for (final piece in line.split(' ')) {
          expect(words, contains(piece), reason: '"$piece" 로 잘렸다 — 줄: $lines');
        }
      }
    });
    testWidgets('운영 공지가 관리자 미리보기와 같은 줄로 꺾인다 (R7)', (tester) async {
      // 기대값은 관리자 미리보기(notice-preview.js · 동봉 Pretendard)를 Chromium 으로 그려
      // 글자마다 줄을 잰 값이다(2026-09-24). 한쪽 규칙이나 치수가 바뀌면 여기서 갈라진다.
      await pumpCard(
        tester,
        notice('live', title: '개인정보처리방침이 **9월 30일**에 바뀌어요', body: body),
      );
      expect(linesOf(tester, titleOf('live')), ['개인정보처리방침이 9월 30일에', '바뀌어요']);
      expect(linesOf(tester, bodyOf('live')), [
        '카드 그림을 만드는 업체가 하나 늘어요. 자세한',
        '내용은 방침에서 확인할 수 있어요.',
      ]);
    });
  });

  group('그림 있는 공지 — 시안 밖 (임시, 디자이너 시안 전)', () {
    testWidgets('제목 위에 카드 안쪽 폭 16:10, 위 여백은 옆과 같은 14', (tester) async {
      await pumpCard(tester, designNotice(button: policy, image: 'img'));
      final image = tester.getRect(
        find.byKey(const ValueKey('notice-image-design')),
      );
      final cardRect = tester.getRect(card());
      expect(image.width, 294);
      expect(image.height, closeTo(294 * 10 / 16, 0.01));
      expect(image.top - cardRect.top, 14);
      expect(image.left - cardRect.left, 14);
      expect(tester.getTopLeft(titleOf('design')).dy - image.bottom, 20);
      // 모서리는 같은 카드 안의 버튼과 같은 8
      final clip = tester.widget<ClipRRect>(
        find.ancestor(
          of: find.byKey(const ValueKey('notice-image-design')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(ElumDialogButton.radius));
    });

    testWidgets('R5 · N3 그림을 못 받으면 자리째 없애고 글만 — 위 여백도 24 로 돌아온다', (
      tester,
    ) async {
      await pumpCard(tester, designNotice(button: policy, image: 'broken-a'));
      expect(find.byKey(const ValueKey('notice-image-design')), findsNothing);
      expect(
        tester.getTopLeft(titleOf('design')).dy - tester.getTopLeft(card()).dy,
        24,
      );
      expect(
        tester.getSize(card()),
        const Size(322, 244),
        reason: '그림 없는 공지와 같다',
      );
    });
  });

  group('N4 · R4 길 때', () {
    testWidgets('360×640 · 글꼴 2.0 · 그림 · 긴 제목 · 1000자 — 넘치지 않고 누를 것은 전부 보인다', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final longButton = NoticeButton(
        label: '베타 한도 자세히 보기',
        url: Uri.parse('https://elum.app/beta'),
      );
      await pumpCard(
        tester,
        notice(
          'a',
          image: 'img',
          button: longButton,
          title: '베타 기간에는 **하루 3개**까지 만들 수 있어요 곧 더 늘어나요 기다려 주세요',
          body: '가나다라마바사 ' * 140,
        ),
      );
      // 여기까지 왔으면 오버플로가 없다 (flutter_test_config 가 오버플로를 실패로 만든다)

      const screen = Rect.fromLTWH(0, 0, 360, 640);
      for (final target in [
        closeButton(),
        linkButton('a'),
        find.byType(NoticeHideToggle),
      ]) {
        final rect = tester.getRect(target);
        expect(
          screen.contains(rect.topLeft) &&
              screen.contains(rect.bottomRight - const Offset(1, 1)),
          isTrue,
          reason: '$target 가 화면 밖이다: $rect',
        );
      }
      expect(
        tester.getSize(card()).height,
        lessThanOrEqualTo(640 * 0.75 + 0.01),
      );

      // 글 자리를 밀어도 버튼은 제자리다
      final buttonBefore = tester.getRect(linkButton('a'));
      final bodyTop = tester.getTopLeft(bodyOf('a')).dy;
      await tester.drag(
        find.byKey(const ValueKey('notice-scroll-a')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(bodyOf('a')).dy,
        lessThan(bodyTop),
        reason: '스크롤되지 않았다',
      );
      expect(tester.getRect(linkButton('a')), buttonBefore);
    });

    for (final scale in [2.0, 3.0]) {
      testWidgets('글꼴 $scale · 360 폭에서도 "일주일간 보지 않기"가 잘리지 않는다', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpCard(tester, designNotice(button: policy));

        final label = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(NoticeHideToggle),
            matching: find.byType(RichText),
          ),
        );
        expect(label.didExceedMaxLines, isFalse);
        // 누를 것만 2배에서 멈춘다 — 그보다 낮으면 2배를 쓰는 보호자의 글자까지 괜히 작아진다
        expect(label.textScaler.scale(14), 28);
      });
    }
  });

  group('보지 않기', () {
    testWidgets('일수가 7 이 아니면 "N일간 보지 않기"', (tester) async {
      await pumpCard(tester, designNotice(), hideDays: 3);
      expect(find.bySemanticsLabel('3일간 보지 않기'), findsOneWidget);
    });

    testWidgets('상태까지 읽히고 글자까지 눌리며 누름 영역은 44 이상', (tester) async {
      final hide = ValueNotifier(false);
      await pumpCard(tester, designNotice(), hide: hide);

      final toggle = find.bySemanticsLabel('일주일간 보지 않기');
      expect(
        tester.getSemantics(toggle),
        containsSemantics(
          hasCheckedState: true,
          isChecked: false,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));

      // 동그라미가 아니라 글자 끝을 눌러도 켜진다
      await tester.tap(
        find.descendant(
          of: find.byType(NoticeHideToggle),
          matching: find.byType(RichText),
        ),
      );
      await tester.pumpAndSettle();
      expect(hide.value, isTrue);
      expect(tester.getSemantics(toggle), containsSemantics(isChecked: true));
    });

    testWidgets('꺼짐은 흰 원 + 청록 테두리, 켜짐은 민트로 찬다 (`채크_라운드` Default·enable)', (
      tester,
    ) async {
      final hide = ValueNotifier(false);
      await pumpCard(tester, designNotice(), hide: hide);
      BoxDecoration face() =>
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;

      expect(face().color, colors.surface);
      expect((face().border! as Border).top.color, colors.checkIdleBorder);

      hide.value = true;
      await tester.pumpAndSettle();
      expect(face().color, colors.checkDone);
    });
  });

  group('showNoticePopup — 어떻게 닫혔는지와 보지 않기를 돌려준다', () {
    Future<Future<NoticePopupResult>> open(
      WidgetTester tester,
      AppNotice n, {
      NoticeLinkOpener? openLink,
    }) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (c) {
                ctx = c;
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        ),
      );
      final result = showNoticePopup(
        ctx,
        n,
        hideDays: 7,
        imageFor: imageFor,
        openLink: openLink ?? (_) async => true,
      );
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('닫기 — close · 숨기지 않음', (tester) async {
      final result = await open(tester, designNotice(button: policy));
      await tester.tap(closeButton());
      await tester.pumpAndSettle();
      final r = await result;
      expect(r.how, NoticeCloseHow.close);
      expect(r.hide, isFalse);
      // 닫히는 모습이 끝난 뒤에 돌아왔다 — 다음 공지가 겹쳐 뜨지 않는다
      expect(find.byType(ModalBarrier), findsOneWidget, reason: '홈의 막 하나만 남는다');
      expect(card(), findsNothing);
    });

    testWidgets('보지 않기 체크 후 닫기 — 숨긴다', (tester) async {
      final result = await open(tester, designNotice());
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.tap(closeButton());
      await tester.pumpAndSettle();
      expect((await result).hide, isTrue);
    });

    testWidgets('링크 — link · 체크돼 있으면 숨긴다', (tester) async {
      final result = await open(tester, designNotice(button: policy));
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.tap(linkButton('design'));
      await tester.pumpAndSettle();
      final r = await result;
      expect(r.how, NoticeCloseHow.link);
      expect(r.hide, isTrue);
    });

    testWidgets('바깥(어두운 배경) — outside · 체크돼 있으면 숨긴다', (tester) async {
      final result = await open(tester, designNotice());
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      final r = await result;
      expect(r.how, NoticeCloseHow.outside);
      expect(r.hide, isTrue);
    });

    testWidgets('안드로이드 뒤로가기 — outside', (tester) async {
      final result = await open(tester, designNotice());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      final r = await result;
      expect(r.how, NoticeCloseHow.outside);
      expect(r.hide, isFalse);
    });

    testWidgets('#385 C 배경 막 이름이 영어 Dismiss 가 아니다', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, designNotice());
      expect(find.bySemanticsLabel('Dismiss'), findsNothing);
      expect(find.bySemanticsLabel(noticeBarrierLabel), findsOneWidget);
      handle.dispose();
    });
  });

  group('#385 C 접근성', () {
    testWidgets('누를 수 있는 것은 전부 이름이 있다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, designNotice(button: policy, image: 'img'));
      expectLabeledButton(tester, '닫기');
      expectLabeledButton(tester, '방침 보기');
      expect(unnamedTapTargets(tester), isEmpty);
      handle.dispose();
    });

    testWidgets('`방침 보기` 의 영역이 제목·본문을 덮지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, designNotice(button: policy));

      Rect globalRectOf(String label) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        // 노드 좌표를 화면 좌표로 옮긴다
        var rect = node.rect;
        SemanticsNode? n = node;
        while (n != null) {
          if (n.transform != null) {
            rect = MatrixUtils.transformRect(n.transform!, rect);
          }
          n = n.parent;
        }
        return rect;
      }

      final link = globalRectOf('방침 보기');
      final visible = tester.getRect(linkButton('design'));
      expect(link.overlaps(tester.getRect(titleOf('design'))), isFalse);
      expect(link.overlaps(tester.getRect(bodyOf('design'))), isFalse);
      expect(link.width, closeTo(visible.width, 1));
      expect(link.height, closeTo(visible.height, 1));
      handle.dispose();
    });
  });
}

/// RichText 의 글 조각별 색. 조각 글자 → 색.
///
/// 비교하기 쉽게 끊지 말라는 표시를 걷어낸다. 표시가 어디 있는지 볼 때는 [raw].
Map<String, Color?> _spansOf(
  WidgetTester tester,
  Finder finder, {
  bool raw = false,
}) {
  final rich = tester.widget<RichText>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  final out = <String, Color?>{};
  final base = rich.text.style?.color;
  rich.text.visitChildren((span) {
    if (span is TextSpan && span.text != null && span.text!.isNotEmpty) {
      final key = raw ? span.text! : span.text!.replaceAll('\u2060', '');
      out[key] = span.style?.color ?? base;
    }
    return true;
  });
  return out;
}

/// 1×1 투명 PNG — 네트워크 없이 "그림이 있다"를 흉내 낸다.
final _onePixelPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0B, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x00, 0x02, 0x00,
  0x00, 0x05, 0x00, 0x01, 0x7A, 0x5E, 0xAB, 0x3F, 0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
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

/// 그려진 글을 줄마다 나눈다 (끊지 말라는 표시는 걷어낸다).
List<String> linesOf(WidgetTester tester, Finder finder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  final text = paragraph.text.toPlainText();
  final painter = TextPainter(
    text: paragraph.text,
    textAlign: paragraph.textAlign,
    textDirection: TextDirection.ltr,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.constraints.maxWidth);
  final lines = <String>[];
  var offset = 0;
  while (offset < text.length) {
    final range = painter.getLineBoundary(TextPosition(offset: offset));
    if (range.end <= offset) {
      offset++;
      continue;
    }
    lines.add(
      text.substring(offset, range.end).replaceAll('\u2060', '').trim(),
    );
    offset = range.end;
  }
  painter.dispose();
  return lines;
}
