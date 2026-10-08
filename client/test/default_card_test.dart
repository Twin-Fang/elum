import 'dart:async';
import 'dart:typed_data';

import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/state/provider_retry.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/default_card_art.dart';
import 'package:elum/shared/models/character.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/card_title_finder.dart';
import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';

/// 그림 없는 카드의 기본 카드 (이슈 #458).
///
/// 예전에는 그림을 못 받으면 프로필과 상관없이 **고양이가 고정**으로 나왔다.
/// 발달장애인에게 "옷 입기" 카드에 고양이가 나오면 카드 뜻이 흐려진다. 그림이 없으면
/// 보호자에게는 점선 자리 + `사진 추가`, 이룸이에게는 번호색 배경에 제목을 크게 보여준다.
/// 시안이 없어 **임시 시안**이다.
void main() {
  useFigmaViewport();

  const title = '옷을 입어요';
  const description = '학교에 입고 갈 옷을 차례대로 입어요';
  const card = ActionCard(id: 's1', title: title, description: description);

  // 1x1 PNG (유효한 파일이라 디코딩도 통과한다).
  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xDF, 0xC0, 0xF0,
    0x1F, 0x00, 0x06, 0x80, 0x02, 0x7F, 0x10, 0x4C, 0x1B, 0xE1, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  final catSvg = svgWithAsset(AppAssets.character(CardCharacter.cat));

  Widget wrap({
    required Future<Uint8List?> Function() fetch,
    String routineId = 'r1',
    ActionCard target = card,
    ActionCardLayout layout = ActionCardLayout.review,
    VoidCallback? onAddPhoto,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      // 앱과 같게 — 실패한 조회를 저절로 다시 부르지 않는다
      retry: elumProviderRetry,
      overrides: [
        cardImageProvider.overrideWith((ref, key) => fetch()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 345,
                height: 431,
                child: ActionCardView(
                  card: target,
                  index: 0,
                  routineId: routineId,
                  layout: layout,
                  onAddPhoto: onAddPhoto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('보호자 화면 — 점선 자리 + 사진 추가', () {
    testWidgets('E14 서버에 그림이 없으면(null) 기본 카드다 — 고양이가 아니다', (tester) async {
      await tester.pumpWidget(wrap(fetch: () async => null));
      await tester.pumpAndSettle();

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(find.text('사진 추가'), findsOneWidget);
      expect(catSvg, findsNothing);
    });

    testWidgets('E14 그림을 받다가 실패해도(error) 기본 카드다', (tester) async {
      await tester.pumpWidget(wrap(fetch: () async => throw Exception('502')));
      await tester.pumpAndSettle();

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(catSvg, findsNothing);
    });

    testWidgets('E14 아직 저장되지 않은 카드(local)는 요청 없이 바로 기본 카드다',
        (tester) async {
      var requested = false;
      await tester.pumpWidget(
        wrap(
          routineId: 'local',
          fetch: () async {
            requested = true;
            return png;
          },
        ),
      );
      await tester.pump();

      expect(requested, isFalse);
      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
    });

    // E15 — 로딩 중에 기본 카드가 잠깐 비쳤다 사라지면 깜빡인다.
    testWidgets('E15 받는 중에는 기본 카드도 고양이도 그리지 않는다', (tester) async {
      final pending = Completer<Uint8List?>();
      await tester.pumpWidget(wrap(fetch: () => pending.future));
      await tester.pump();

      expect(find.byType(DefaultCardPhotoSlot), findsNothing);
      expect(find.text('사진 추가'), findsNothing);
      expect(catSvg, findsNothing);

      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
    });

    testWidgets('그림이 있으면 기본 카드는 나오지 않는다', (tester) async {
      await tester.pumpWidget(wrap(fetch: () async => png));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(DefaultCardPhotoSlot), findsNothing);
    });

    testWidgets('제목은 그대로 번호 옆 줄에 있다', (tester) async {
      await tester.pumpWidget(wrap(fetch: () async => null));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    // E17 — #456(사진 바꾸기)이 연결하기 전에는 눌러도 아무 일이 없다.
    testWidgets('E17 onAddPhoto 가 없으면 누를 수 없고 낭독기에도 버튼으로 잡히지 않는다',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(fetch: () async => null));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(DefaultCardPhotoSlot),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(find.bySemanticsLabel('사진 추가'), findsNothing);
      handle.dispose();
    });

    testWidgets('E17 onAddPhoto 가 있으면 누르면 불리고 사진 추가 버튼으로 읽힌다',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        wrap(fetch: () async => null, onAddPhoto: () => taps++),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.bySemanticsLabel('사진 추가')),
        containsSemantics(label: '사진 추가', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.text('사진 추가'));
      expect(taps, 1);
      handle.dispose();
    });

    // 바이트는 왔는데 그림이 아니다 — 깨진 이미지 아이콘 대신 기본 카드가 나와야 한다.
    testWidgets('E14 받은 바이트를 그림으로 읽지 못해도 기본 카드다', (tester) async {
      await tester.pumpWidget(
        wrap(fetch: () async => Uint8List.fromList(const [1, 2, 3, 4])),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(catSvg, findsNothing);
    });

    testWidgets('E8 글자를 200% 로 키워도 넘치지 않는다', (tester) async {
      await tester.pumpWidget(
        wrap(fetch: () async => null, textScale: 2.0, onAddPhoto: () {}),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('사진 추가'), findsOneWidget);
    });
  });

  group('이룸이 화면 — 번호색 배경에 제목을 크게', () {
    testWidgets('E14 그림이 없으면 제목이 그림 자리에 크게 나오고 줄에는 번호만 남는다',
        (tester) async {
      await tester.pumpWidget(
        wrap(fetch: () async => null, layout: ActionCardLayout.childDetail),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DefaultCardTitleArt), findsOneWidget);
      // 제목이 한 번만 나온다 — 그림 자리에만.
      final titleFinder = cardTitle(title);
      expect(titleFinder, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DefaultCardTitleArt),
          matching: titleFinder,
        ),
        findsOneWidget,
      );
      // 줄에는 제목이 남지 않는다
      expect(find.byKey(const ValueKey('title-in-row')), findsNothing);
      expect(find.text('1'), findsOneWidget);
      expect(catSvg, findsNothing);
      expect(find.text('사진 추가'), findsNothing);
    });

    testWidgets('번호색(카드 테두리색) 배경을 깐다', (tester) async {
      await tester.pumpWidget(
        wrap(fetch: () async => null, layout: ActionCardLayout.childDetail),
      );
      await tester.pumpAndSettle();

      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(DefaultCardTitleArt),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, const Color(0xFF93DBCC)); // 1번 카드 = 민트 번호색
    });

    testWidgets('E15 받는 중에는 제목이 줄에 그대로 있다(그림이 올 수 있다)', (tester) async {
      final pending = Completer<Uint8List?>();
      await tester.pumpWidget(
        wrap(fetch: () => pending.future, layout: ActionCardLayout.childDetail),
      );
      await tester.pump();

      expect(find.byType(DefaultCardTitleArt), findsNothing);
      expect(cardTitle(title), findsOneWidget);

      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(DefaultCardTitleArt), findsOneWidget);
      expect(cardTitle(title), findsOneWidget);
    });

    testWidgets('그림이 있으면 제목은 줄에 그대로 있다', (tester) async {
      await tester.pumpWidget(
        wrap(fetch: () async => png, layout: ActionCardLayout.childDetail),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DefaultCardTitleArt), findsNothing);
      expect(cardTitle(title), findsOneWidget);
    });

    // E16 — 제목이 아주 길거나 글자를 키워도 잘리거나 넘치지 않는다.
    testWidgets('E8·E16 긴 제목을 200% 로 키워도 넘치지 않고 …로 자르지 않는다', (tester) async {
      const long = '천천히 학교로 가서 친구들에게 인사하고 자리에 앉아요';
      await tester.pumpWidget(
        wrap(
          fetch: () async => null,
          layout: ActionCardLayout.childDetail,
          target: const ActionCard(id: 's1', title: long, description: '설명'),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(cardTitle(long));
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.maxLines, isNull);
      // 그림 자리 안에 들어온다
      final art = tester.getRect(find.byType(DefaultCardTitleArt));
      final rendered = tester.getRect(cardTitle(long));
      expect(art.contains(rendered.topLeft), isTrue);
      expect(art.contains(rendered.bottomRight), isTrue);
    });

    testWidgets('E9 작은 폰(320×568)에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(
        wrap(fetch: () async => null, layout: ActionCardLayout.childDetail),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DefaultCardTitleArt), findsOneWidget);
    });

    testWidgets('제목을 낭독기가 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(fetch: () async => null, layout: ActionCardLayout.childDetail),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(title), findsOneWidget);
      handle.dispose();
    });
  });
}
