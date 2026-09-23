@Tags(['golden'])
library;

import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/notice/domain/app_notice.dart';
import 'package:elum/features/notice/presentation/notice_popup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/precache_images.dart';

/// 공지 팝업 — 시안 대조와 변형 (이슈 #390).
///
/// **시안 대조** `figma/notice_1090-4922.png` — 카드만 322×244 로 찍는다. 시안 노드
/// (`팝업` 931:4878 의 `방침` 변형 1090:4922)와 크기가 같아 `tool/figma_props.py` 가
/// 그대로 맞댄다. 대조 데이터는 시안 글 그대로다 — 글이 다르면 차이가 통째로 붉어진다.
///
/// **변형** `goldens/notice_*.png` — 시안이 그리지 않은 모양(링크 없음·그림·긴 본문·
/// 글꼴 2.0)을 화면째 찍어 회귀를 막는다. 시안 대조가 아니다 — 처음 찍은 것이 틀리면
/// 틀린 것을 고정하므로 #390 댓글에 캡처를 남겨 사람이 본다.
void main() {
  useFigmaViewport();

  final policy = NoticeButton(
    label: '방침 보기',
    url: Uri.parse('https://twin-fang.github.io/elum/privacy.html'),
  );

  /// 시안(1090:4922) 글 그대로. 제목의 줄바꿈도 시안이 넣은 자리다.
  AppNotice design({NoticeButton? button, String? image}) => AppNotice(
    id: 'c056722d',
    revision: 2,
    title: '개인정보처리방침이 \n**9월 30일**에 바뀌어요',
    body: '카드 그림을 만드는 업체가 하나 늘어요.\n자세한 내용은 방침에서 확인할 수 있어요',
    button: button,
    imageUrl: image,
  );

  /// 운영에 실제로 올라간 공지 글 그대로 — 관리자가 줄을 넣지 않았다(#370 운영 실측).
  /// 앱이 스스로 어디서 꺾는지(#385 A)를 보는 자리다.
  final live = AppNotice(
    id: 'c056722d',
    revision: 2,
    title: '개인정보처리방침이 **9월 30일**에 바뀌어요',
    body: '카드 그림을 만드는 업체가 하나 늘어요. 자세한 내용은 방침에서 확인할 수 있어요.',
    button: policy,
  );

  ImageProvider imageFor(String url) => MemoryImage(_sampleImage());

  testWidgets('공지 팝업 — 방침 (Figma 1090:4922)', (tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            // 카드 크기 그대로 찍으려고 제약을 푼다. 팝업(Dialog)은 제약이 있으면 화면을
            // 다 차지하므로, 풀어 줘야 카드만큼만 선다 — 시안 노드(322×244)와 크기가 같아진다.
            body: Center(
              child: UnconstrainedBox(
                child: RepaintBoundary(
                  key: const ValueKey('card-shot'),
                  child: NoticePopupCard(
                    notice: design(button: policy),
                    hideDays: 7,
                    hideChecked: ValueNotifier(false),
                    onClose: () {},
                    onLinkOpened: () {},
                    openLink: (_) async => true,
                    imageFor: imageFor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('card-shot'))),
      const Size(322, 244),
    );
    await expectLater(
      find.byKey(const ValueKey('card-shot')),
      matchesGoldenFile('figma/notice_1090-4922.png'),
    );
  });

  /// 화면째 찍는다 — 어두운 막과 카드가 어디 뜨는지까지 보이게.
  Future<void> shoot(
    WidgetTester tester,
    String name,
    AppNotice notice, {
    Size size = const Size(393, 852),
    double textScale = 1.0,
    bool check = false,
  }) async {
    tester.view.physicalSize = size;
    if (textScale != 1.0) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
    }
    late BuildContext ctx;
    const shot = ValueKey('shot');
    await tester.pumpWidget(
      RepaintBoundary(
        key: shot,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (c) {
                ctx = c;
                return Scaffold(
                  backgroundColor: AppColors.light.background,
                  body: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    );
    showNoticePopup(ctx, notice, hideDays: 7, imageFor: imageFor);
    await tester.pumpAndSettle();
    // 그림은 비동기로 풀린다 — 기다리지 않으면 "받는 중" 자리를 정답으로 굳힌다
    await precacheAllImages(tester);
    await tester.pumpAndSettle();
    if (check) {
      await tester.tap(find.bySemanticsLabel('일주일간 보지 않기'));
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byKey(shot),
      matchesGoldenFile('goldens/notice_$name.png'),
    );
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }

  testWidgets('변형 — 운영 공지 글 그대로 (어절 줄바꿈)', (tester) async {
    await shoot(tester, 'live', live);
  });

  testWidgets('변형 — R1 링크 없음: 닫기 하나', (tester) async {
    await shoot(tester, 'no_link', design());
  });

  testWidgets('변형 — 보지 않기 체크', (tester) async {
    await shoot(tester, 'checked', design(button: policy), check: true);
  });

  testWidgets('변형 — 그림 있는 공지 (시안 밖 · 임시)', (tester) async {
    await shoot(tester, 'image', design(button: policy, image: 'img'));
  });

  testWidgets('변형 — R2 긴 버튼 문구', (tester) async {
    await shoot(
      tester,
      'long_button',
      AppNotice(
        id: 'beta',
        revision: 1,
        title: '베타 기간에는 **하루 3개**까지 만들 수 있어요',
        body: '더 많이 만들 수 있게 준비하고 있어요.',
        button: NoticeButton(
          label: '베타 한도 자세히 보기',
          url: Uri.parse('https://elum.app/beta'),
        ),
      ),
    );
  });

  final long = AppNotice(
    id: 'long',
    revision: 1,
    title: '베타 기간 이용 안내 — **하루 3개**까지 만들 수 있어요',
    body: List.filled(
      12,
      '보호자님이 적어 주신 일과를 카드로 만들 때 그림을 그리는 데 시간이 걸려요. '
      '베타 기간에는 하루에 만들 수 있는 개수를 정해 두었어요.',
    ).join('\n'),
    button: policy,
  );

  testWidgets('변형 — N4 긴 본문 (글 자리만 스크롤)', (tester) async {
    await shoot(tester, 'long_body', long);
  });

  testWidgets('변형 — R4 360×640 · 글꼴 2.0 · 긴 본문', (tester) async {
    await shoot(
      tester,
      'font2_360',
      long,
      size: const Size(360, 640),
      textScale: 2.0,
    );
  });

  testWidgets('변형 — R4 360×640 · 글꼴 2.0 · 시안 글', (tester) async {
    await shoot(
      tester,
      'font2_360_design',
      design(button: policy),
      size: const Size(360, 640),
      textScale: 2.0,
    );
  });
}

/// 16:10 그림 대신 — 네트워크 없이 그릴 수 있는 작은 PNG.
/// 한 번 만든 것을 다시 쓴다 (골든마다 같은 그림).
Uint8List _sampleImage() => _png ??= Uint8List.fromList(_samplePngBytes);
Uint8List? _png;

/// 16×10 PNG — 하늘·땅·해 세 덩어리. 그림 자리가 어디에 어떤 크기로 서는지만 보면 된다.
const _samplePngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x0A,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x32, 0xDC, 0x49, 0xCB, 0x00, 0x00, 0x00,
  0x32, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0xBC, 0xF6, 0xE1, 0x35,
  0x03, 0x29, 0x80, 0x05, 0xBF, 0xB4, 0xE6, 0xB3, 0x6A, 0x38, 0xFB, 0xBA,
  0x54, 0x2B, 0x03, 0x03, 0x03, 0x13, 0x03, 0x89, 0x80, 0x64, 0x0D, 0x8C,
  0xA4, 0xFA, 0x81, 0x74, 0x1B, 0x42, 0xCF, 0xEF, 0xA2, 0xAD, 0x0D, 0xB4,
  0xD7, 0x00, 0x00, 0x6D, 0xD9, 0x0A, 0x54, 0x78, 0xA7, 0xD1, 0x25, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];
