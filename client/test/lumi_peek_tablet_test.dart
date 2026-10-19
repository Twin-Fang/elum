import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/lumi_peek.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_backdrop.dart';
import 'package:elum/core/layout/adaptive_page_frame.dart';
import 'package:elum/core/layout/screen_layout_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';
import 'helpers/child_demo_overrides.dart';
import 'helpers/fake_dio.dart';
import 'helpers/stub_routine_repository.dart';

/// 일과 만들기 로딩의 루미: 폰은 화면 가장자리에서 엿본다. 태블릿은 폰 비율 열 끝이 아니라 **창 가장자리**에서 엿봐야 한다.
/// 깨지면: 태블릿 가로에서 루미가 가운데 열 모서리에 반쯤 걸려 허공에 떠 보인다.
void main() {
  Future<void> pumpLoading(
    WidgetTester tester,
    Size size,
    RoutineLoadingKind kind,
  ) async {
    setTestWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...childDemoOverrides(isElumiDevice: false),
          routineRepositoryProvider.overrideWithValue(
            PendingRoutineRepository(),
          ),
          offlineDioOverride(),
          speechServiceProvider.overrideWithValue(_Silent()),
        ],
        child: adaptiveTestApp(
          home: AdaptivePageFrame(
            kind: ScreenLayoutKind.adaptive,
            child: RoutineFlowBackdrop(
              tone: RoutineLoadingScreen.auroraOf(kind),
              child: RoutineLoadingScreen(kind: kind),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // 들어오는 연출이 끝난 자세까지 기다린다
    await tester.pump(const Duration(seconds: 3));
  }

  /// 로딩 화면은 단계 타이머가 계속 생긴다. 검증만 하고 끝내면 `A Timer is still pending` 이 터지므로 끝까지 돌려 치운다
  Future<void> drainTimers(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('폰 393x852: 루미 자리는 화면 폭 그대로 (회귀 0)', (tester) async {
    await pumpLoading(
      tester,
      const Size(393, 852),
      RoutineLoadingKind.generate,
    );

    final rect = tester.getRect(find.byType(LumiPeek));
    expect(rect.left, closeTo(0, 0.5));
    expect(rect.right, closeTo(393, 0.5));
    await drainTimers(tester);
  });

  testWidgets('가로 태블릿 1194x834: 루미 자리가 창 양끝까지 닿는다', (tester) async {
    await pumpLoading(
      tester,
      const Size(1194, 834),
      RoutineLoadingKind.generate,
    );

    final rect = tester.getRect(find.byType(LumiPeek));
    expect(rect.left, closeTo(0, 0.5));
    expect(
      rect.right,
      closeTo(1194, 0.5),
      reason: '열 끝(약 790)이 아니라 창 오른쪽 끝에서 엿본다',
    );
    await drainTimers(tester);
  });
}

class _Silent implements SpeechService {
  @override
  Future<bool> speak(
    String text, {
    String language = 'ko',
    StoredSpeechSource? stored,
  }) async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
