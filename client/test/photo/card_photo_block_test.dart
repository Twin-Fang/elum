import 'dart:async';

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/card_photo.dart';
import 'package:elum/features/guardian/data/card_photo_picker.dart';
import 'package:elum/features/guardian/presentation/widgets/card_image.dart';
import 'package:elum/features/guardian/presentation/widgets/card_photo_block.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/semantics_audit.dart';
import '../helpers/test_storage.dart';
import 'fake_photo_picker.dart';

/// 카드 그림을 사진으로 바꾸는 블록 (#456) — 진입 칩 · 고르기 시트 · 권한 거부 ·
/// 올리는 중 · 실패 · 성공.
///
/// 카메라·갤러리는 [FakePhotoPicker] 가, 서버는 [FakeAdapter] 가 대신한다.
void main() {
  useFigmaViewport();

  const put = 'PUT /api/routines/r1/steps/c1/image';
  const ok = {'id': 'c1', 'imagePath': 'k/new.jpg'};

  const routine = Routine(
    id: 'r1',
    title: '비 오는 날 학교에 가요',
    status: 'PENDING_REVIEW',
    steps: [
      ActionCard(id: 'c1', title: '옷을 입어요', description: '옷을 입어요', imagePath: 'k/old.jpg'),
    ],
  );

  late FakePhotoPicker picker;
  late _FakeSettings settings;
  late ProviderContainer container;

  Widget host(
    Map<String, Object?> routes, {
    Duration delay = Duration.zero,
    bool mounted = true,
    double textScale = 1.0,
  }) {
    container = ProviderContainer(
      overrides: [
        fakeDioOverride(routes, delay: delay),
        testStorageOverride(onboardingCompleted: true),
        cardPhotoPickerProvider.overrideWithValue(picker),
        photoSettingsProvider.overrideWithValue(settings),
      ],
    );
    container.read(routineFlowProvider.notifier).resumeDraft(routine);
    return UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: mounted
                  ? const CardPhotoBlock(routineId: 'r1', stepId: 'c1')
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  /// dio 사슬이 Timer 를 끼고 돌아 여러 번 나눠 흘린다.
  Future<void> settle(WidgetTester tester, {int times = 12}) async {
    for (var i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  String? imagePathNow() =>
      container.read(routineFlowProvider).routine!.steps.single.imagePath;

  setUp(() {
    picker = FakePhotoPicker([]);
    settings = _FakeSettings();
  });

  tearDown(() => container.dispose());

  Future<void> openPickSheet(WidgetTester tester) async {
    await tester.tap(find.text('사진 바꾸기'));
    await settle(tester);
  }

  group('진입 칩과 고르기 시트', () {
    testWidgets('그림 위에 사진 바꾸기 칩이 있다', (tester) async {
      await tester.pumpWidget(host({}));
      await settle(tester);

      expect(find.text('사진 바꾸기'), findsOneWidget);
    });

    testWidgets('미리보기는 카드 그림 칸과 같은 비율(313:230)이다 — 띠가 아니다', (tester) async {
      await tester.pumpWidget(host({}));
      await settle(tester);

      // 시트 폭 전체의 띠(약 2.4:1)였을 때는 사진이 카드에서 어떻게 잘리는지 알 수 없었다 (통합 E2E 실측).
      final size = tester.getSize(
        find
            .ancestor(
              of: find.byType(CardImage),
              matching: find.byType(AspectRatio),
            )
            .first,
      );

      expect(size.width / size.height, closeTo(313 / 230, 0.02));
    });

    testWidgets('칩을 누르면 사진 찍기·갤러리에서 고르기·닫기와 안내가 뜬다', (tester) async {
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);

      expect(find.text('사진 찍기'), findsOneWidget);
      expect(find.text('갤러리에서 고르기'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
      // 개인정보 원칙 — 찍기 전에 말한다
      expect(find.text('얼굴이나 개인정보가 나오지 않게 찍어 주세요'), findsOneWidget);
    });

    testWidgets('닫기 — 아무 일도 없다 (E: 시트 닫기)', (tester) async {
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);

      await tester.tap(find.text('닫기'));
      await settle(tester);

      expect(find.text('사진 찍기'), findsNothing);
      expect(picker.calls, isEmpty);
      expect(imagePathNow(), 'k/old.jpg');
    });
  });

  group('성공', () {
    testWidgets('사진 찍기 → 올리기 → imagePath 가 새 열쇠로 바뀐다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({put: ok}));
      await openPickSheet(tester);

      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(picker.calls, [PhotoSource.camera]);
      expect(imagePathNow(), 'k/new.jpg');
      // 끝나면 다시 바꿀 수 있다
      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(find.text('사진을 올리지 못했어요'), findsNothing);
    });

    testWidgets('갤러리에서 고르기도 같은 길로 올린다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({put: ok}));
      await openPickSheet(tester);

      await tester.tap(find.text('갤러리에서 고르기'));
      await settle(tester);

      expect(picker.calls, [PhotoSource.gallery]);
      expect(imagePathNow(), 'k/new.jpg');
    });
  });

  group('선택 취소', () {
    testWidgets('사진을 안 고르고 돌아오면 아무 일도 없다 — 요청도 실패 화면도 없다', (tester) async {
      picker = FakePhotoPicker([const PhotoPickCancelled()]);
      final adapterRoutes = <String, Object?>{put: ok};
      await tester.pumpWidget(host(adapterRoutes));
      await openPickSheet(tester);

      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(imagePathNow(), 'k/old.jpg');
      expect(find.text('사진을 올리지 못했어요'), findsNothing);
      expect(find.text('사진을 올리고 있어요'), findsNothing);
      expect(find.text('사진 바꾸기'), findsOneWidget);
    });
  });

  group('권한 거부', () {
    testWidgets('카메라 거부 — 이유와 갤러리 우회 경로를 준다', (tester) async {
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.camera)]);
      await tester.pumpWidget(host({put: ok}));
      await openPickSheet(tester);

      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('카메라를 쓸 수 없어요'), findsOneWidget);
      expect(find.text('휴대폰 설정에서 카메라를 켜면 사진을 찍을 수 있어요'), findsOneWidget);
      expect(find.text('갤러리에서 고르기'), findsOneWidget);
      expect(find.text('설정 열기'), findsOneWidget);
    });

    testWidgets('거부 화면에서 갤러리 — 앱은 계속 돌고 사진을 올린다', (tester) async {
      picker = FakePhotoPicker([
        const PhotoPickDenied(PhotoSource.camera),
        PhotoPicked(fakeJpeg()),
      ]);
      await tester.pumpWidget(host({put: ok}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      await tester.tap(find.text('갤러리에서 고르기'));
      await settle(tester);

      expect(picker.calls, [PhotoSource.camera, PhotoSource.gallery]);
      expect(imagePathNow(), 'k/new.jpg');
    });

    testWidgets('설정 열기 — 휴대폰 설정으로 보낸다', (tester) async {
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.camera)]);
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      await tester.tap(find.text('설정 열기'));
      await settle(tester);

      expect(settings.opened, 1);
    });

    testWidgets('설정을 못 열면 알리고 화면에 남는다 — E-PHOTO-SETTINGS', (tester) async {
      settings.result = false;
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.camera)]);
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      await tester.tap(find.text('설정 열기'));
      await settle(tester);

      expect(find.text('E-PHOTO-SETTINGS'), findsOneWidget);
      expect(find.text('카메라를 쓸 수 없어요'), findsOneWidget);
    });

    testWidgets('설정을 열 수 없는 휴대폰(안드로이드)은 버튼을 감춘다', (tester) async {
      settings.available = false;
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.camera)]);
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('설정 열기'), findsNothing);
      expect(find.text('갤러리에서 고르기'), findsOneWidget);
    });

    testWidgets('거부 화면에서 뒤로 — 아무 일도 없다', (tester) async {
      final handle = tester.ensureSemantics();
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.camera)]);
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('뒤로 가기'));
      // 전체 화면 전환이 끝나도록 충분히 흘린다
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('카메라를 쓸 수 없어요'), findsNothing);
      expect(find.text('사진 바꾸기'), findsOneWidget);
      expect(imagePathNow(), 'k/old.jpg');
      handle.dispose();
    });

    testWidgets('갤러리(사진) 거부 — 사진 찍기가 우회 경로다', (tester) async {
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.gallery)]);
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);
      await tester.tap(find.text('갤러리에서 고르기'));
      await settle(tester);

      expect(find.text('사진을 볼 수 없어요'), findsOneWidget);
      expect(find.text('사진 찍기'), findsOneWidget);
    });
  });

  group('올리는 중', () {
    testWidgets('올리는 동안 문구를 보이고 칩은 감춘다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({put: ok}, delay: const Duration(seconds: 2)));
      await openPickSheet(tester);

      await tester.tap(find.text('사진 찍기'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('사진을 올리고 있어요'), findsOneWidget);
      expect(find.text('사진 바꾸기'), findsNothing);
      expect(imagePathNow(), 'k/old.jpg', reason: '아직 끝나지 않았다');

      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(imagePathNow(), 'k/new.jpg');
      // 새 그림을 받는 요청(지연 2초)이 끝나도록 흘린다
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('고르는 중에 다시 눌러도 한 번만 고른다 (연속 탭)', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())])..hold = Completer<void>();
      await tester.pumpWidget(host({put: ok}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await tester.pump(const Duration(milliseconds: 100));

      // 사진 앱이 떠 있는 동안 칩을 또 눌러도 시트가 다시 뜨지 않는다
      await tester.tap(find.text('사진 바꾸기'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('사진 찍기'), findsNothing);

      picker.hold!.complete();
      await settle(tester);
      expect(picker.calls.length, 1);
    });

    testWidgets('올리는 중에는 두 번째 요청이 나가지 않는다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg()), PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({put: ok}, delay: const Duration(seconds: 2)));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await tester.pump(const Duration(milliseconds: 500));

      // 칩이 없으니 누를 수 없다 — 두 번째 고르기는 시작되지 않는다
      expect(find.text('사진 바꾸기'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(picker.calls.length, 1);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('실패', () {
    testWidgets('서버 500 — 문구·에러 코드·다시 하기, 같은 사진으로 다시 올린다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      final routes = <String, Object?>{
        put: const FakeHttpError(500, errorCode: 'ROUTINE_STEP_IMAGE_SAVE_FAILED'),
      };
      await tester.pumpWidget(host(routes));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('사진을 올리지 못했어요'), findsOneWidget);
      expect(find.text('ROUTINE_STEP_IMAGE_SAVE_FAILED'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);
      expect(imagePathNow(), 'k/old.jpg', reason: '실패하면 옛 그림 그대로다');

      // 서버가 살아났다 — 사진 앱을 다시 열지 않고 같은 사진으로 보낸다
      routes[put] = ok;
      await tester.tap(find.text('다시 하기'));
      await settle(tester);

      expect(picker.calls.length, 1, reason: '다시 찍게 하지 않는다');
      expect(imagePathNow(), 'k/new.jpg');
      expect(find.text('사진을 올리지 못했어요'), findsNothing);
    });

    testWidgets('400(크기·형식) — 서버 문구를 보이고 다시 하기는 고르기 시트를 연다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({
        put: const FakeHttpError(
          400,
          errorCode: 'ROUTINE_STEP_IMAGE_TOO_LARGE',
          errorMessage: '사진은 5MB 까지 올릴 수 있어요.',
        ),
      }));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('사진은 5MB 까지 올릴 수 있어요.'), findsOneWidget);
      expect(find.text('ROUTINE_STEP_IMAGE_TOO_LARGE'), findsOneWidget);

      await tester.tap(find.text('다시 하기'));
      await settle(tester);
      expect(find.text('사진 찍기'), findsOneWidget, reason: '같은 사진은 또 거절된다 — 다른 사진을 고른다');
    });

    testWidgets('403 — 다시 해도 같으니 확인만 있다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({
        put: const FakeHttpError(403, errorCode: 'ROUTINE_NOT_CREATOR', errorMessage: '내가 만든 일과만 고칠 수 있어요.'),
      }));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('내가 만든 일과만 고칠 수 있어요.'), findsOneWidget);
      expect(find.text('ROUTINE_NOT_CREATOR'), findsOneWidget);
      expect(find.text('다시 하기'), findsNothing);

      await tester.tap(find.text('확인'));
      await settle(tester);
      expect(find.text('사진을 올리지 못했어요'), findsNothing);
      expect(find.text('사진 바꾸기'), findsOneWidget);
    });

    testWidgets('404 — 지워진 카드다, 알리고 닫는다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({
        put: const FakeHttpError(404, errorCode: 'ROUTINE_STEP_NOT_FOUND', errorMessage: '카드를 찾을 수 없어요.'),
      }));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('ROUTINE_STEP_NOT_FOUND'), findsOneWidget);
      expect(find.text('다시 하기'), findsNothing);
    });

    testWidgets('인터넷이 끊기면 안내와 E-NET-OFFLINE — 같은 사진으로 다시 한다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({put: const FakeOffline()}));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('E-NET-OFFLINE'), findsOneWidget);
      expect(find.text('인터넷 연결을 확인해주세요'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);
    });

    testWidgets('사진 앱을 여는 데 실패하면 E-PHOTO-PICK (갤러리 앱이 없는 휴대폰 등)', (tester) async {
      picker = FakePhotoPicker([const PhotoPickFailed(PhotoFailure.pick)]);
      await tester.pumpWidget(host({}));
      await openPickSheet(tester);
      await tester.tap(find.text('갤러리에서 고르기'));
      await settle(tester);

      expect(find.text('사진을 올리지 못했어요'), findsOneWidget);
      expect(find.text('E-PHOTO-PICK'), findsOneWidget);

      // 다시 하기 → 고르기 시트가 다시 열려 카메라로 우회할 수 있다
      await tester.tap(find.text('다시 하기'));
      await settle(tester);
      expect(find.text('사진 찍기'), findsOneWidget);
    });
  });

  group('올리는 도중 화면이 사라질 때', () {
    testWidgets('시트를 닫아도 업로드는 끝나고 새 그림이 반영된다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host({put: ok}, delay: const Duration(seconds: 2)));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await tester.pump(const Duration(milliseconds: 500));

      // 블록이 사라진다(시트를 내렸다)
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ));
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);

      expect(imagePathNow(), 'k/new.jpg');
      expect(tester.takeException(), isNull);
    });
  });

  group('접근성·글자 크기', () {
    testWidgets('칩·시트 버튼에 읽을 이름이 있다 (TalkBack)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host({}));
      await settle(tester);

      expect(find.bySemanticsLabel('사진 바꾸기'), findsWidgets);
      expect(unnamedTapTargets(tester), isEmpty);

      await openPickSheet(tester);
      expect(find.bySemanticsLabel('사진 찍기'), findsWidgets);
      expect(find.bySemanticsLabel('갤러리에서 고르기'), findsWidgets);
      expect(find.bySemanticsLabel('닫기'), findsWidgets);
      expect(unnamedTapTargets(tester), isEmpty);
      handle.dispose();
    });

    testWidgets('칩의 누름 영역은 48×48 이상이다', (tester) async {
      await tester.pumpWidget(host({}));
      await settle(tester);

      final size = tester.getSize(find.byKey(CardPhotoBlock.chipTapKey));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('글자 200% — 고르기 시트가 깨지지 않는다', (tester) async {
      await tester.pumpWidget(host({}, textScale: 2.0));
      await settle(tester);
      await openPickSheet(tester);

      expect(find.text('사진 찍기'), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('글자 200% — 실패 화면이 깨지지 않는다', (tester) async {
      picker = FakePhotoPicker([PhotoPicked(fakeJpeg())]);
      await tester.pumpWidget(host(
        {put: const FakeHttpError(500)},
        textScale: 2.0,
      ));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('다시 하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('글자 200% — 권한 거부 화면이 깨지지 않는다', (tester) async {
      picker = FakePhotoPicker([const PhotoPickDenied(PhotoSource.camera)]);
      await tester.pumpWidget(host({}, textScale: 2.0));
      await openPickSheet(tester);
      await tester.tap(find.text('사진 찍기'));
      await settle(tester);

      expect(find.text('카메라를 쓸 수 없어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeSettings implements PhotoSettings {
  int opened = 0;
  bool result = true;

  @override
  bool available = true;

  @override
  Future<bool> open() async {
    opened++;
    return result;
  }
}
