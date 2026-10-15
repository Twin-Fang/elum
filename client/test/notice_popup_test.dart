import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:elum/features/notice/presentation/widgets/notice_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 공지 팝업 (이슈 #390 · 시안 `팝업` 931:4878 의 `방침` 변형 1090:4922).
///
/// 공지가 앱의 다른 팝업(로그아웃·회원탈퇴·일과 삭제)과 **같은 컴포넌트**가 됐다.
/// 오른쪽 위 ✕ · 위쪽 체크박스 · 슬라이드·점·화살표(#371)는 없다.
void main() {
  useFigmaViewport();

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
  Finder bodyOf(String id) => find.byKey(ValueKey('notice-body-$id'));

  /// 버튼의 색 면(DecoratedBox)


  group('버튼 — R1 · R2', () {
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

    test('https 가 아닌 주소는 열지 않는다 (N12 두 번째 거름)', () async {
      expect(await openNoticeLink(Uri.parse('http://x.test')), isFalse);
      expect(await openNoticeLink(Uri.parse('intent://x')), isFalse);
    });
  });


  group('#385 A 어절 단위 줄바꿈 — 관리자 미리보기와 같은 규칙', () {
    const body = '카드 그림을 만드는 업체가 하나 늘어요. 자세한 내용은 방침에서 확인할 수 있어요.';

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

    testWidgets('링크 — link · 체크돼 있으면 숨긴다', (tester) async {
      final result = await open(tester, designNotice(button: policy));
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.tap(linkButton('design'));
      await tester.pumpAndSettle();
      final r = await result;
      expect(r.how, NoticeCloseHow.link);
      expect(r.hide, isTrue);
    });

  });

}

/// RichText 의 글 조각별 색. 조각 글자 → 색.
///
/// 비교하기 쉽게 끊지 말라는 표시를 걷어낸다. 표시가 어디 있는지 볼 때는 [raw].

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
