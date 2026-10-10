import 'dart:async';

import 'package:elum/core/state/provider_retry.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/card_image_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/card_photo_block.dart';
import 'package:elum/features/guardian/presentation/widgets/default_card_art.dart';
import 'package:elum/features/guardian/presentation/widgets/pictogram_art.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/card_title_finder.dart';
import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/test_storage.dart';

/// 그림 자리에 무료 픽토그램을 보여준다 (#469).
///
/// 우선순위: 사진/AI 그림 > 픽토그램 > 기본 카드(옛 카드). 받는 중에는 빈 자리.
void main() {
  useFigmaViewport();

  // flutter_svg 는 읽은 그림을 전역 캐시에 든다. 앞 테스트가 채운 캐시가 자산 읽기 실패 시험을 가리지 않게 비운다.
  setUp(svg.cache.clear);

  const title = '옷을 입어요';
  const dressId = 'get_dressed_,_to';
  const card = ActionCard(
    id: 's1',
    title: title,
    description: '학교에 입고 갈 옷을 차례대로 입어요',
    pictogramId: dressId,
  );

  final png = Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xDF, 0xC0, 0xF0,
    0x1F, 0x00, 0x06, 0x80, 0x02, 0x7F, 0x10, 0x4C, 0x1B, 0xE1, 0x00, 0x00,
    0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  Widget wrap({
    Future<Uint8List?> Function()? fetch,
    ActionCard target = card,
    ActionCardLayout layout = ActionCardLayout.review,
    double textScale = 1.0,
    AssetBundle? bundle,
    Widget? child,
  }) {
    Widget body = child ??
        Center(
          child: SizedBox(
            width: 345,
            height: 431,
            child: ActionCardView(
              card: target,
              index: 0,
              routineId: 'r1',
              layout: layout,
            ),
          ),
        );
    if (bundle != null) body = DefaultAssetBundle(bundle: bundle, child: body);
    return ProviderScope(
      retry: elumProviderRetry,
      overrides: [
        cardImageProvider.overrideWith((ref, key) => (fetch ?? () async => null)()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(body: body),
        ),
      ),
    );
  }

  /// SVG 는 비동기로 읽혀 pumpAndSettle 만으로는 첫 그림이 안 나올 수 있다.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  // 픽토그램은 전용 로더로 그려 `SvgPicture.asset` 이 아니다 — 열쇠로 찾는다
  Finder pictogramSvg(String id) => find.byKey(ValueKey('pictogram-$id'));
  final dress = pictogramSvg(dressId);

  group('보호자 카드확인', () {
    testWidgets('E3 그림이 없고 pictogramId 가 있으면 픽토그램을 그린다 (기본 카드 아님)', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.byType(PictogramArt), findsOneWidget);
      expect(dress, findsOneWidget);
      expect(find.byType(DefaultCardPhotoSlot), findsNothing);
      expect(find.text('사진 추가'), findsNothing);
    });

    testWidgets('픽토그램은 칸 안에 contain 으로, 흰 바탕에 여백을 두고 앉는다', (tester) async {
      await tester.pumpWidget(wrap());
      await settle(tester);

      final svg = tester.widget<SvgPicture>(dress);
      expect(svg.fit, BoxFit.contain);
      final art = tester.getRect(find.byType(PictogramArt));
      final pic = tester.getRect(dress);
      expect(art.width / art.height, closeTo(313 / 230, 0.02), reason: '그림 칸 비율');
      expect(pic.left, greaterThan(art.left), reason: '테두리에 붙지 않는다');
      expect(pic.top, greaterThan(art.top));
      final bg = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(PictogramArt), matching: find.byType(ColoredBox)).first,
      );
      expect(bg.color, Colors.white);
    });

    testWidgets('E4 사진·AI 그림이 있으면 픽토그램은 안 나온다', (tester) async {
      await tester.pumpWidget(wrap(fetch: () async => png));
      await settle(tester);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(PictogramArt), findsNothing);
      expect(dress, findsNothing);
    });

    testWidgets('E5 받는 중에는 빈 자리다 — 픽토그램도 기본 카드도 번쩍이지 않는다', (tester) async {
      final pending = Completer<Uint8List?>();
      await tester.pumpWidget(wrap(fetch: () => pending.future));
      await tester.pump();

      expect(find.byType(PictogramArt), findsNothing);
      expect(find.byType(DefaultCardPhotoSlot), findsNothing);

      pending.complete(null);
      await settle(tester);
      expect(find.byType(PictogramArt), findsOneWidget);
    });

    testWidgets('E1 pictogramId 가 없는 옛 카드는 기본 카드다', (tester) async {
      await tester.pumpWidget(
        wrap(target: const ActionCard(id: 's1', title: title, description: 'd')),
      );
      await settle(tester);

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(find.byType(PictogramArt), findsNothing);
    });

    testWidgets('E2 카탈로그에 없는 id 는 기본 카드다 (직접 만든 카드도 방어)', (tester) async {
      await tester.pumpWidget(
        wrap(
          target: const ActionCard(id: 's1', title: title, description: 'd', pictogramId: 'no_such'),
        ),
      );
      await settle(tester);

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(find.byType(PictogramArt), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('E6 받은 바이트가 깨졌어도 픽토그램이 있으면 그것을 보여준다', (tester) async {
      await tester.pumpWidget(wrap(fetch: () async => Uint8List.fromList(const [1, 2, 3, 4])));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(tester);

      expect(find.byType(PictogramArt), findsOneWidget);
    });

    testWidgets('E7 자산을 못 읽으면 기본 카드로 대체하고 화면은 멀쩡하다', (tester) async {
      // flutter_svg 는 읽기 실패를 errorBuilder 로 넘기면서 비동기 오류도 한 번 흘려 보낸다.
      // 그 오류가 테스트를 즉시 실패시키므로 이 구역에서만 따로 받아 우리가 넣은 오류인지 확인한다.
      final leaked = <Object>[];
      // 다른 테스트가 이미 그린 심볼이면 flutter_svg 의 전역(살아 있는) 캐시가 읽기를 건너뛰어
      // 실패를 못 만든다 — 이 테스트에서만 쓰는 심볼(hairbrush)로 시험한다.
      const broken = ActionCard(id: 's1', title: title, description: 'd', pictogramId: 'hairbrush');
      await runZonedGuarded(() async {
        await tester.pumpWidget(wrap(target: broken, bundle: _BrokenPictogramBundle()));
        // 읽기 실패 → errorBuilder → 다음 프레임에 기본 카드로 갈아 끼운다
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }, (e, _) => leaked.add(e));

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(pictogramSvg('hairbrush'), findsNothing, reason: '픽토그램 그림은 내려간다');
      expect(tester.takeException(), isNull, reason: '화면은 예외 없이 그려진다');
      expect(leaked.map((e) => e.toString()), everyElement(contains('테스트: 자산을 읽을 수 없다')));
    });

    testWidgets('낭독기는 그림 대신 카드 제목을 읽고, 안쪽 SVG 는 따로 읽지 않는다', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(PictogramArt),
          matching: find.bySemanticsLabel(title),
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('E10 글자를 200% 로 키워도 넘치지 않는다', (tester) async {
      await tester.pumpWidget(wrap(textScale: 2.0));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(PictogramArt), findsOneWidget);
    });

    testWidgets('E9 작은 폰(320×568)에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(PictogramArt), findsOneWidget);
    });
  });

  group('이룸이 카드 상세', () {
    testWidgets('E8 픽토그램이 있으면 제목을 그림 자리로 올리지 않고 줄에 둔다', (tester) async {
      await tester.pumpWidget(wrap(layout: ActionCardLayout.childDetail));
      await settle(tester);

      expect(find.byType(PictogramArt), findsOneWidget);
      expect(find.byType(DefaultCardTitleArt), findsNothing);
      expect(find.byKey(const ValueKey('title-in-row')), findsOneWidget);
      expect(cardTitle(title), findsWidgets);
    });

    testWidgets('pictogramId 가 없으면 예전 그대로 제목이 그림 자리로 올라간다 (#458)', (tester) async {
      await tester.pumpWidget(
        wrap(
          layout: ActionCardLayout.childDetail,
          target: const ActionCard(id: 's1', title: title, description: 'd'),
        ),
      );
      await settle(tester);

      expect(find.byType(DefaultCardTitleArt), findsOneWidget);
      expect(find.byKey(const ValueKey('title-in-row')), findsNothing);
    });

    testWidgets('사진이 있으면 제목은 줄에 있고 픽토그램은 없다', (tester) async {
      await tester.pumpWidget(wrap(layout: ActionCardLayout.childDetail, fetch: () async => png));
      await settle(tester);

      expect(find.byType(PictogramArt), findsNothing);
      expect(find.byKey(const ValueKey('title-in-row')), findsOneWidget);
    });

    testWidgets('E10 200% 에서도 넘치지 않는다', (tester) async {
      await tester.pumpWidget(wrap(layout: ActionCardLayout.childDetail, textScale: 2.0));
      await settle(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('엣지', () {
    testWidgets('E11 쉼표가 든 verb 심볼과 폴백(go_,_to)을 그린다', (tester) async {
      for (final id in const ['go_,_to', 'brush_teeth_,_to', 'wash_hands_,_to', 'umbrella', 'milk']) {
        await tester.pumpWidget(
          wrap(target: ActionCard(id: 's', title: title, description: 'd', pictogramId: id)),
        );
        await settle(tester);
        expect(pictogramSvg(id), findsOneWidget, reason: id);
        expect(tester.takeException(), isNull, reason: id);
      }
    });

    testWidgets('E12 가장 큰 SVG(rug, 107KB)도 3초 안에 그린다', (tester) async {
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        wrap(target: const ActionCard(id: 's', title: title, description: 'd', pictogramId: 'rug')),
      );
      await settle(tester);
      sw.stop();
      expect(pictogramSvg('rug'), findsOneWidget);
      expect(sw.elapsedMilliseconds, lessThan(3000));
    });

    testWidgets('E13 목록에서 여러 카드가 동시에 픽토그램을 그린다', (tester) async {
      const ids = ['get_dressed_,_to', 'brush_teeth_,_to', 'umbrella', 'milk', 'wash_hands_,_to', 'go_,_to'];
      await tester.pumpWidget(
        wrap(
          child: ListView(
            children: [
              for (var i = 0; i < ids.length; i++)
                SizedBox(
                  width: 345,
                  height: 431,
                  child: ActionCardView(
                    card: ActionCard(id: 's$i', title: '카드 $i', description: 'd', pictogramId: ids[i]),
                    index: i,
                    routineId: 'r1',
                  ),
                ),
            ],
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(PictogramArt), findsAtLeastNWidgets(1));
    });
  });

  group('카드 수정 시트의 그림 칸(CardPhotoBlock)', () {
    late ProviderContainer container;

    Widget sheetBlock(Routine routine, {Future<Uint8List?> Function()? fetch}) {
      container = ProviderContainer(
        overrides: [
          fakeDioOverride(const {}),
          testStorageOverride(onboardingCompleted: true),
          cardImageProvider.overrideWith((ref, key) => (fetch ?? () async => null)()),
        ],
      );
      container.read(routineFlowProvider.notifier).resumeDraft(routine);
      return UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(24),
                child: CardPhotoBlock(routineId: 'r1', stepId: 's1'),
              ),
            ),
          ),
        ),
      );
    }

    Routine routineOf(ActionCard c) => Routine(id: 'r1', status: 'PENDING_REVIEW', steps: [c]);

    testWidgets('픽토그램을 그리고 사진 바꾸기 칩은 그대로 있다', (tester) async {
      await tester.pumpWidget(sheetBlock(routineOf(card)));
      await settle(tester);

      expect(find.byType(PictogramArt), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(find.byType(DefaultCardPhotoSlot), findsNothing);
    });

    testWidgets('pictogramId 가 없으면 점선 사진 추가 자리다 (#456 훅 그대로)', (tester) async {
      await tester.pumpWidget(
        sheetBlock(routineOf(const ActionCard(id: 's1', title: title, description: 'd'))),
      );
      await settle(tester);

      expect(find.byType(DefaultCardPhotoSlot), findsOneWidget);
      expect(find.byType(PictogramArt), findsNothing);
    });

    testWidgets('사진이 있으면 픽토그램은 안 나온다', (tester) async {
      await tester.pumpWidget(sheetBlock(routineOf(card), fetch: () async => png));
      await settle(tester);

      expect(find.byType(PictogramArt), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('복제·수정 뒤에도 값이 남는다', () {
    test('사진을 바꿔도(applyStepImage) pictogramId 가 남는다', () {
      final container = ProviderContainer(
        overrides: [
          fakeDioOverride(const {}),
          testStorageOverride(onboardingCompleted: true),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(routineFlowProvider.notifier)
        ..resumeDraft(const Routine(id: 'r1', status: 'PENDING_REVIEW', steps: [card]));

      notifier.applyStepImage('s1', 'k/new.jpg');

      final step = container.read(routineFlowProvider).routine!.steps.single;
      expect(step.imagePath, 'k/new.jpg');
      expect(step.pictogramId, dressId);
    });
  });
}

/// 픽토그램 자산만 읽지 못하는 번들 — 다른 자산(폰트 등)은 그대로 준다.
class _BrokenPictogramBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('assets/pictograms/')) {
      return Future<ByteData>.error(FlutterError('테스트: 자산을 읽을 수 없다'));
    }
    return rootBundle.load(key);
  }
}
