import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/routine_progress_ring.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_summary_tile.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 시스템 글자를 키운 보호자에게 홈·설정이 깨지지 않는다 (디자인 원칙 §7-2).
///
/// 넘침(overflow)은 `flutter_test_config.dart` 가 자동으로 실패시킨다. 가장 긴 줄이 나오는
/// 상태(보상 문구가 있는 일과 · 날짜가 붙는 지난 일과 · 연결된 이룸이 휴대폰)로 본다.
void main() {
  useFigmaViewport();

  const scales = [1.0, 1.3, 2.0, 3.1];

  Routine routine(
    String id,
    String title, {
    String reward = '',
    int percent = 0,
    DateTime? at,
  }) => Routine(
    id: id,
    title: title,
    status: 'CONFIRMED',
    rewardText: reward,
    progressPercent: percent,
    scheduledAt: at,
    steps: [
      ActionCard(
        id: 'c1',
        stepOrder: 1,
        description: '첫 단계',
        completed: percent >= 50,
      ),
      ActionCard(
        id: 'c2',
        stepOrder: 2,
        description: '둘째 단계',
        completed: percent >= 100,
      ),
    ],
  );

  Widget scaled(double scale, Widget child) => ScreenUtilInit(
    designSize: const Size(393, 852),
    useInheritedMediaQuery: true,
    builder: (context, _) => MaterialApp(
      theme: AppTheme.light,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: child,
    ),
  );

  Widget home(double scale) => ProviderScope(
    overrides: [
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      routineRepositoryProvider.overrideWithValue(
        _FontScaleRepo(
          routines: [
            routine('r1', '스스로 옷을 입어요', reward: '유튜브 시청 20분', percent: 50),
            routine('r2', '밥 먹기 전에 손을 씻어요', reward: '마이구미 5개 먹기', percent: 100),
            routine('r3', '제목만 있는 일과'),
          ],
          past: [
            routine(
              'p1',
              '학교에 갈 준비를 해요',
              reward: '좋아하는 노래 들으며 학교 가기',
              percent: 50,
              at: DateTime(2026, 9, 20),
            ),
          ],
        ),
      ),
      memberProvider.overrideWith((ref) async => const Member(nickname: '하늘이')),
    ],
    child: scaled(scale, const GuardianHomeScreen()),
  );

  for (final scale in scales) {
    testWidgets('보호자 홈 — 글꼴 $scale 에서 넘치지 않는다', (tester) async {
      await tester.pumpWidget(home(scale));
      await tester.pumpAndSettle();

      expect(find.byType(RoutineSummaryTile), findsWidgets);
      // 진행률은 한 덩어리로 남는다 — `25` / `%` 로 쪼개지지 않는다.
      final percent = find.text('50%');
      expect(percent, findsWidgets);
      expect(
        tester.getSize(percent.first).height,
        lessThan(24 * scale.clamp(1.0, 3.1)),
      );
    });

    testWidgets('보호자 설정 — 글꼴 $scale 에서 넘치지 않고 줄이 겹치지 않는다', (tester) async {
      final auth = _FakeAuth();
      final router = GoRouter(
        initialLocation: Routes.guardianSettings,
        routes: [
          GoRoute(
            path: Routes.guardianSettings,
            builder: (_, _) => const GuardianSettingsScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorageOverride(),
            authRepositoryProvider.overrideWithValue(auth),
            consentBundleProvider.overrideWith(
              (ref) async => ConsentBundle.bundled,
            ),
            appVersionProvider.overrideWith((ref) async => '1.24.1'),
            linkStatusProvider.overrideWith(
              (ref) async => Attempt.ok(
                LinkStatus(
                  devices: [
                    LinkedDevice(linkId: 'l1', linkedAt: DateTime(2026, 9, 18)),
                  ],
                ),
              ),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              builder: (context, app) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: app!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 이룸이 휴대폰 줄이 바로 아래 줄과 겹치지 않는다
      final link = tester.getRect(find.text('이룸이 휴대폰').first);
      final next = tester.getRect(find.text('함께하는 사람').first);
      expect(link.bottom, lessThanOrEqualTo(next.top));
    });
  }

  testWidgets('타일 높이 — 기본 글꼴은 시안 68 · 105 그대로, 키우면 늘어난다', (tester) async {
    Future<Size> sizeAt(double scale, {bool tall = false}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [testStorageOverride()],
          child: scaled(
            scale,
            Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 361,
                  child: RoutineSummaryTile(
                    routine: routine(
                      't',
                      '스스로 옷을 입어요',
                      reward: '유튜브 시청 20분',
                      percent: 25,
                      at: DateTime(2026, 9, 20),
                    ),
                    progress: 0.25,
                    showDate: tall,
                    onRerun: tall ? () {} : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(RoutineSummaryTile));
    }

    final shortSize = await sizeAt(1.0);
    final tallSize = await sizeAt(1.0, tall: true);
    expect(shortSize.height, 68.h);
    expect(tallSize.height, 105.h);
    expect((await sizeAt(2.0)).height, greaterThan(68.h));
  });

  testWidgets('진행률 글자는 링 안에서 한 줄이다', (tester) async {
    await tester.pumpWidget(
      scaled(
        3.1,
        const Scaffold(
          body: Center(child: RoutineProgressRing(progress: 0.25)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 글자 상자 자체는 줄이기 전 크기다 — 한 줄이면 높이가 글자 한 줄 안쪽이다
    expect(tester.getSize(find.text('25%')).height, lessThan(12 * 3.1 * 1.5));
    final fitted = tester.getSize(
      find.descendant(
        of: find.byType(RoutineProgressRing),
        matching: find.byType(FittedBox),
      ),
    );
    final ring = tester.getSize(find.byType(RoutineProgressRing));
    expect(fitted.width, lessThanOrEqualTo(ring.width));
  });
}

class _FakeAuth extends AuthRepository {
  _FakeAuth()
    : super(
        dio: Dio(),
        storage: InMemoryStorage(),
        tokens: InMemoryTokenStore(),
        sdk: OAuthSdk(),
      );
}

class _FontScaleRepo with FakeRewardApi implements RoutineRepository {
  // 카드확인 카드 추가 (#444) — 이 테스트는 쓰지 않는다
  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  _FontScaleRepo({required this.routines, required this.past});

  final List<Routine> routines;
  final List<Routine> past;

  @override
  Future<List<Routine>> getMyRoutines() async => routines;

  @override
  Future<List<Routine>> getTodayRoutines() async => routines;

  @override
  Future<List<Routine>> getPastRoutines() async => past;

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => const [];

  @override
  Future<RoutineQuestion> generateQuestion(String rawInputText) async =>
      const RoutineQuestion();

  @override
  Future<Routine> createRoutine({
    required String rawInputText,
    required Set<SupportGoal> goals,
    List<String> answers = const [],
    String rewardText = '',
    String rewardPresetKey = '',
    String idempotencyKey = '',
  }) async => const Routine(id: 'new');

  @override
  Future<Routine> confirm(Routine routine) async => routine;

  @override
  Future<AppFailure?> deleteStep(String routineId, String stepId) async => null;

  @override
  Future<({Routine routine, AppFailure? failure})> updateStep(
    Routine routine,
    String stepId, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
}
