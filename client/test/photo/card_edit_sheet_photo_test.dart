import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/data/card_photo_picker.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/card_edit_sheet.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/test_storage.dart';
import 'fake_photo_picker.dart';

/// 카드 수정 시트에 그림 칸이 들어온다 (#456).
///
/// 서버 id 가 있는 카드에서만 `사진 바꾸기` 칩이 뜨고, 시트가 키보드·작은 폰·큰 글자에서
/// 깨지지 않으며, 올리는 도중 시트를 닫아도 결과가 사라지지 않는다.
void main() {
  useFigmaViewport();

  const put = 'PUT /api/routines/r1/steps/c1/image';
  const ok = {'id': 'c1', 'imagePath': 'k/new.jpg'};

  const routine = Routine(
    id: 'r1',
    status: 'PENDING_REVIEW',
    steps: [
      ActionCard(
        id: 'c1',
        title: '옷을 입어요',
        description: '학교에 입고 갈 옷을 차례대로 입어요',
        stepOrder: 1,
        imagePath: 'k/old.jpg',
      ),
      ActionCard(id: 'local_9', title: '내가 넣은 카드', description: '서버에 없어요', stepOrder: 2),
    ],
  );

  late FakePhotoPicker picker;
  late ProviderContainer container;

  /// 서버 응답·사진 고르기를 가짜로 끼운 컨테이너. 이전 것이 있으면 버리고 새로 만든다.
  void useContainer(Map<String, Object?> routes, {Duration delay = Duration.zero}) {
    container = ProviderContainer(
      overrides: [
        fakeDioOverride(routes, delay: delay),
        testStorageOverride(onboardingCompleted: true),
        cardPhotoPickerProvider.overrideWithValue(picker),
        speechServiceProvider.overrideWithValue(_SilentSpeech()),
      ],
    );
    container.read(routineFlowProvider.notifier).resumeDraft(routine);
  }

  Widget app(Widget home, {double textScale = 1.0}) => UncontrolledProviderScope(
    container: container,
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      builder: (_, _) => home is MaterialApp
          ? home
          : MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
              home: home,
            ),
    ),
  );

  /// 시트를 여는 버튼이 있는 화면.
  Widget sheetHost({CardPhotoTarget? photo, bool add = false, double textScale = 1.0}) {
    return app(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => add
                  ? CardEditSheet.showAdd(context, onSubmit: (_, _) async => true)
                  : CardEditSheet.show(
                      context,
                      title: '옷을 입어요',
                      description: '학교에 입고 갈 옷을 차례대로 입어요',
                      photo: photo,
                    ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
      textScale: textScale,
    );
  }

  Future<void> settle(WidgetTester tester, {int times = 12}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('열기'));
    await settle(tester);
  }

  String? imagePathOf(String id) => container
      .read(routineFlowProvider)
      .routine!
      .steps
      .firstWhere((s) => s.id == id)
      .imagePath;

  setUp(() {
    picker = FakePhotoPicker([]);
    useContainer({put: ok});
  });

  tearDown(() => container.dispose());

  final target = CardPhotoTarget.of(routineId: 'r1', stepId: 'c1');

  group('칩을 두는 조건 — 서버 id 가 있는 수정 시트만', () {
    test('서버 id 가 없으면 대상이 만들어지지 않는다', () {
      expect(CardPhotoTarget.of(routineId: '', stepId: 'c1'), isNull);
      expect(CardPhotoTarget.of(routineId: 'local', stepId: 'c1'), isNull);
      expect(CardPhotoTarget.of(routineId: 'r1', stepId: ''), isNull);
      expect(CardPhotoTarget.of(routineId: 'r1', stepId: 'local_9'), isNull);
      expect(CardPhotoTarget.of(routineId: 'r1', stepId: 'c1'), isNotNull);
    });

    testWidgets('대상이 있으면 그림 칸과 칩이 뜨고 제목·설명은 그대로 있다', (tester) async {
      await tester.pumpWidget(sheetHost(photo: target));
      await openSheet(tester);

      expect(find.text('카드 수정'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(find.text('옷을 입어요'), findsOneWidget);
      expect(find.text('완료'), findsOneWidget);
    });

    testWidgets('대상이 없으면 칩이 없다', (tester) async {
      await tester.pumpWidget(sheetHost());
      await openSheet(tester);

      expect(find.text('카드 수정'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsNothing);
    });

    testWidgets('추가 시트에는 칩이 없다', (tester) async {
      await tester.pumpWidget(sheetHost(add: true));
      await openSheet(tester);

      expect(find.text('새로운 카드 추가'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsNothing);
    });
  });

  group('카드확인 화면에서', () {
    Widget review() {
      final router = GoRouter(
        initialLocation: Routes.routineReview,
        routes: [
          GoRoute(
            path: Routes.routineReview,
            builder: (context, state) => const CardReviewScreen(),
          ),
          GoRoute(
            path: Routes.guardian,
            builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
          ),
        ],
      );
      return app(MaterialApp.router(theme: AppTheme.light, routerConfig: router));
    }

    Future<void> pumpReview(WidgetTester tester, Routine r) async {
      await tester.pumpWidget(review());
      container.read(routineFlowProvider.notifier).state = RoutineFlowState(routine: r);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('서버 카드의 수정 시트에는 사진 바꾸기 칩이 있다', (tester) async {
      await pumpReview(tester, routine);

      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);

      expect(find.text('카드 수정'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsOneWidget);
    });

    testWidgets('서버에 저장되지 않은 일과(id 없음)는 칩을 숨긴다', (tester) async {
      await pumpReview(tester, routine.copyWith(id: ''));

      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);

      expect(find.text('카드 수정'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsNothing);
    });

    testWidgets('로컬에서 만든 카드(local_…)는 칩을 숨긴다', (tester) async {
      await pumpReview(tester, routine.copyWith(steps: [routine.steps[1]]));

      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);

      expect(find.text('카드 수정'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsNothing);
    });
  });

  group('올리는 도중 시트를 닫는다', () {
    Future<void> startUpload(WidgetTester tester) async {
      await tester.tap(find.text('사진 바꾸기'));
      await settle(tester);
      await tester.tap(find.text('사진 찍기'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('사진을 올리고 있어요'), findsOneWidget);
    }

    Future<void> dismissSheetByBarrier(WidgetTester tester) async {
      // 시트 위쪽 어두운 배경을 누른다
      await tester.tapAt(const Offset(200, 40));
      await settle(tester, times: 6);
    }

    testWidgets('성공하면 시트가 없어도 새 그림이 카드에 반영된다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      container.dispose();
      useContainer({put: ok}, delay: const Duration(seconds: 2));

      await tester.pumpWidget(sheetHost(photo: target));
      await openSheet(tester);
      await startUpload(tester);

      await dismissSheetByBarrier(tester);
      expect(find.text('카드 수정'), findsNothing, reason: '시트가 닫혔다');

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(imagePathOf('c1'), 'k/new.jpg');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('실패하면 인라인으로 알릴 자리가 없으니 팝업으로 알린다 — 삼키지 않는다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      container.dispose();
      useContainer(
        {put: const FakeHttpError(500, errorCode: 'ROUTINE_STEP_IMAGE_SAVE_FAILED')},
        delay: const Duration(seconds: 2),
      );

      await tester.pumpWidget(sheetHost(photo: target));
      await openSheet(tester);
      await startUpload(tester);

      await dismissSheetByBarrier(tester);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(find.textContaining('사진을 올리지 못했어요'), findsOneWidget);
      expect(find.text('ROUTINE_STEP_IMAGE_SAVE_FAILED'), findsOneWidget);
      expect(imagePathOf('c1'), 'k/old.jpg');
    });
  });

  group('화면 크기·키보드·글자 크기', () {
    testWidgets('키보드가 올라오면 그림 칸을 접고 입력칸이 가려지지 않는다', (tester) async {
      await tester.pumpWidget(sheetHost(photo: target));
      await openSheet(tester);
      expect(find.text('사진 바꾸기'), findsOneWidget);

      showKeyboard(tester);
      await settle(tester);

      // 접힌 그림 칸은 화면에 없다(상태는 살아 있다)
      expect(find.text('사진 바꾸기'), findsNothing);
      // 설명 입력칸이 키보드(852-336=516) 위에 있다
      final desc = tester.getRect(find.byType(TextField).last);
      expect(desc.bottom, lessThan(852 - 336));
      expect(tester.takeException(), isNull);
    });

    for (final size in const {
      'iPhone SE (375×667)': Size(375, 667),
      'Galaxy (360×800)': Size(360, 800),
      'iPhone 16 (393×852)': Size(393, 852),
    }.entries) {
      testWidgets('${size.key} — 시트가 화면 안에 들어오고 완료 버튼이 보인다', (tester) async {
        tester.view.physicalSize = size.value;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(sheetHost(photo: target));
        await openSheet(tester);

        final sheet = tester.getRect(find.byType(CardEditSheet));
        expect(sheet.top, greaterThanOrEqualTo(0));
        final done = tester.getRect(find.text('완료'));
        expect(done.bottom, lessThanOrEqualTo(size.value.height));
        expect(find.text('사진 바꾸기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('글자 200% — 시트가 깨지지 않는다', (tester) async {
      await tester.pumpWidget(sheetHost(photo: target, textScale: 2.0));
      await openSheet(tester);

      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// 소리를 내지 않는 fake — 카드확인 화면이 소리 서비스를 잡아 간다.
class _SilentSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {String language = 'ko'}) async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
