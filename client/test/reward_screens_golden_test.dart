@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/domain/reward_character.dart';
import 'package:elum/features/child/presentation/reward_screen.dart';
import 'package:elum/features/child/presentation/widgets/reward_banner.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'helpers/precache_images.dart';

/// 보상이 보이는 자리들 (이슈 #239).
///
/// **AI를 부르지 않고** 화면을 보기 위한 골든이다. 일과를 실제로 만들면
/// 카드 생성 API가 돌아 비용이 나간다 — 여기서는 만들어진 일과를 넣어 렌더만 한다.
void Function(FlutterErrorDetails)? _originalOnError;

void main() {
  useFigmaViewport();

  // 카드 검토 화면이 읽어주기(TTS)·효과음 플러그인을 붙잡는다. 테스트 환경에는
  // 구현이 없어 `MissingPluginException`이 나므로 채널을 대역으로 막는다.
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'flutter_tts',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (call) async => null,
      );
    }
    messenger.setMockStreamHandler(
      const EventChannel('xyz.luan/audioplayers.global/events'),
      MockStreamHandler.inline(onListen: (args, sink) {}),
    );

    // 플레이어마다 이벤트 채널 이름에 UUID가 붙어 미리 막을 수 없다.
    // 플러그인 없음만 삼키고 나머지 예외는 그대로 올린다 — 진짜 오류를 가리면 안 된다.
    _originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      _originalOnError?.call(details);
    };
  });

  tearDown(() => FlutterError.onError = _originalOnError);

  const routine = Routine(
    id: 'r1',
    title: '아침 등교 준비',
    status: 'CONFIRMED',
    rewardText: '젤리 먹기',
    rewardPresetKey: 'SNACK',
    totalStepCount: 3,
    steps: [
      ActionCard(id: 'c1', stepOrder: 1, description: '세수를 해요'),
      ActionCard(id: 'c2', stepOrder: 2, description: '옷을 입어요'),
      ActionCard(id: 'c3', stepOrder: 3, description: '가방을 메요'),
    ],
  );

  // riverpod 3.x가 `Override` 타입을 export하지 않아 파라미터로 받지 않는다.
  Widget wrap(Widget child) => ProviderScope(
        overrides: [testStorageOverride(nickname: '하늘이')],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          useInheritedMediaQuery: true,
          builder: (context, _) => MaterialApp(
            theme: AppTheme.light,
            home: child is Scaffold ? child : Scaffold(body: child),
          ),
        ),
      );

  testWidgets('이룸이 수행 중 — 상단 고정 바', (tester) async {
    // 수행 화면 전체는 컨페티·TTS가 플랫폼 채널을 잡아 테스트에서 못 띄운다.
    // 이 이슈가 더한 것은 **바 하나**이므로 그것만 찍는다.
    await tester.pumpWidget(wrap(
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('수행 중 (작게)'),
            const SizedBox(height: 8),
            RewardBanner.maybe(routine, compact: true),
            const SizedBox(height: 32),
            const Text('시작·완료 (크게)'),
            const SizedBox(height: 8),
            RewardBanner.maybe(routine),
          ],
        ),
      ),
    ));
    await tester.pump();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/reward_banner_sizes.png'),
    );
  });

  testWidgets('이룸이 완료 — 별과 보상을 함께 보여준다', (tester) async {
    await tester.pumpWidget(wrap(
      const RewardScreen(
        character: RewardCharacter.lumi,
        reward: (emoji: '🍪', text: '젤리 먹기'),
      ),
    ));
    await tester.pump();
    // 별은 PNG라 로딩을 기다려야 그려진다
    await precacheAllImages(tester);
    await tester.pump(const Duration(milliseconds: 800));

    await expectLater(
      find.byType(RewardScreen),
      matchesGoldenFile('goldens/reward_on_complete.png'),
    );
  });

}
