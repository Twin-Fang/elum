import 'dart:async';

import 'package:dio/dio.dart';
import 'package:elum/features/ads/data/ad_banner_loader.dart';
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/core/config/ad_ids.dart';
import 'package:elum/features/ads/data/rewarded_ad_loader.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/credit/application/ad_reward_flow.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/ad_reward.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/credit_fixtures.dart';
import '../helpers/device_viewport.dart';
import '../helpers/fake_ad_reward.dart';
import '../helpers/fake_reward_api.dart';
import '../helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 크레딧 소진 안내의 "광고 보고 더 만들기" (#464).
///
/// 이 안내는 일과 만들기 **진입 전**에만 있다. 지급은 서버 확인 뒤에만이고,
/// 어떤 실패에서도 홈으로 돌아온다.
void main() {
  useFigmaViewport();

  const adButton = '광고 보고 더 만들기';
  const exhausted = '이번 주 크레딧을 모두 사용했어요';

  late FakeAdRewardRepo adRepo;
  late FakeRewardedLoader loader;
  late _Credit credit;

  setUp(() {
    adRepo = FakeAdRewardRepo(statuses: [_granted]);
    loader = FakeRewardedLoader();
    credit = _Credit(available: 0);
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    int maxPolls = 3,
    bool adsEnabled = true,
  }) async {
    final router = GoRouter(
      initialLocation: Routes.guardian,
      routes: [
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const GuardianHomeScreen(),
        ),
        GoRoute(
          path: Routes.routineInput,
          builder: (context, state) => const Scaffold(body: Text('일과 입력')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true),
          routineRepositoryProvider.overrideWithValue(_HomeRepo()),
          memberProvider.overrideWith((ref) async => null),
          creditRepositoryProvider.overrideWithValue(credit),
          adsEnabledProvider.overrideWithValue(adsEnabled),
          // 홈 배너는 이 테스트의 관심사가 아니다 — SDK 를 띄우지 않는다.
          adBannerLoaderProvider.overrideWithValue(_NoBanner()),
          adRewardFlowProvider.overrideWith(
            (ref) => AdRewardFlow(
              repository: adRepo,
              loader: loader,
              adsEnabled: ref.watch(adsEnabledProvider),
              pollInterval: const Duration(seconds: 1),
              maxPolls: maxPolls,
            ),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapCreate(WidgetTester tester) async {
    await tester.tap(find.text('새로운 일과 만들기'));
    await tester.pumpAndSettle();
  }

  group('제안 — 어디에 보이나', () {
    testWidgets('크레딧을 다 썼고 서버가 켜 두었으면 소진 안내에 버튼이 있다', (tester) async {
      await pumpHome(tester);
      await tapCreate(tester);

      expect(find.textContaining(exhausted), findsOneWidget);
      expect(find.text(adButton), findsOneWidget);
      expect(find.text('닫기'), findsOneWidget);
    });

    // 지금 운영 상태 — 배포해도 화면이 바뀌지 않아야 한다.
    testWidgets('서버가 꺼 두었으면 지금 안내 그대로다', (tester) async {
      adRepo.offer = const AdRewardOffer(
        enabled: false,
        // 다른 값이 남아 있어도 꺼짐이 이긴다.
        creditsPerView: 2,
        remainingToday: 5,
      );
      await pumpHome(tester);
      await tapCreate(tester);

      expect(find.textContaining(exhausted), findsOneWidget);
      expect(find.text(adButton), findsNothing);
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('제안 조회가 실패해도 안내는 그대로 뜬다', (tester) async {
      adRepo.offerError = const AppFailure(fault: NetworkFault.offline);
      await pumpHome(tester);
      await tapCreate(tester);

      expect(find.textContaining(exhausted), findsOneWidget);
      expect(find.text(adButton), findsNothing);
    });

    testWidgets('광고를 띄울 수 없는 환경이면 서버에 묻지도 않는다', (tester) async {
      await pumpHome(tester, adsEnabled: false);
      await tapCreate(tester);

      expect(find.text(adButton), findsNothing);
      expect(adRepo.offerCalls, 0);
    });

    // 광고로 크레딧이 늘어도 진행 중인 생성이 끝나야 새로 만들 수 있다.
    testWidgets('이미 만들고 있다는 안내에는 광고를 제안하지 않는다', (tester) async {
      credit = _Credit(
        available: 30,
        inProgress: [
          {'jobId': 'j1', 'kind': 'ROUTINE_CREATE'},
        ],
      );
      await pumpHome(tester);
      await tapCreate(tester);

      expect(find.textContaining('이미 일과를 만들고 있어요'), findsOneWidget);
      expect(find.text(adButton), findsNothing);
    });

    testWidgets('크레딧이 남아 있으면 안내도 광고도 없이 들어간다', (tester) async {
      credit = _Credit(available: 10);
      await pumpHome(tester);
      await tapCreate(tester);

      expect(find.text('일과 입력'), findsOneWidget);
      expect(find.text(adButton), findsNothing);
      expect(adRepo.offerCalls, 0);
    });

    testWidgets('닫기를 누르면 광고 없이 홈으로 돌아온다', (tester) async {
      await pumpHome(tester);
      await tapCreate(tester);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();

      expect(find.text('새로운 일과 만들기'), findsOneWidget);
      expect(adRepo.sessionCalls, 0);
      expect(loader.shownNonces, isEmpty);
    });
  });

  group('시청 → 지급', () {
    testWidgets('서버가 지급을 확인한 뒤에야 크레딧이 늘고 알린다', (tester) async {
      final gate = Completer<AdRewardSessionStatus>();
      adRepo = _GatedRepo(gate);
      await pumpHome(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GuardianHomeScreen)),
      );
      // 설정 카드처럼 크레딧 요약을 계속 보고 있는 화면을 흉내 낸다.
      final sub = container.listen(creditSummaryProvider, (_, _) {});
      addTearDown(sub.close);
      await tester.pump();
      expect(sub.read().value?.available, 0);

      await tapCreate(tester);
      final readsBefore = credit.calls;
      await tester.tap(find.text(adButton));
      // 광고 시청이 끝나고 서버 확인을 기다리는 중이다.
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('크레딧을 확인하고 있어요'), findsOneWidget);

      // 시청만으로는 아무것도 늘지 않는다 — 앱이 먼저 올리지도 다시 읽지도 않는다.
      expect(sub.read().value?.available, 0);
      expect(credit.calls, readsBefore, reason: '지급 전에는 크레딧을 다시 읽지 않는다');
      expect(find.textContaining('받았어요'), findsNothing);

      // 서버가 지급했다.
      credit.available = 2;
      gate.complete(_granted);
      await tester.pumpAndSettle();

      expect(find.textContaining('크레딧 2개를 받았어요'), findsOneWidget);
      expect(sub.read().value?.available, 2);
      expect(loader.shownNonces, ['N1']);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 일과 만들기'), findsOneWidget);
    });

    testWidgets('지급 알림 뒤에도 일과 만들기로 자동 이동하지 않는다', (tester) async {
      await pumpHome(tester);
      await tapCreate(tester);
      await tester.tap(find.text(adButton));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('일과 입력'), findsNothing);
    });
  });

  group('실패 — 코드를 보이고 홈으로 돌아온다', () {
    Future<void> expectBackHome(WidgetTester tester, String code) async {
      expect(find.text(code), findsOneWidget, reason: '에러 코드가 보여야 한다');
      expect(credit.calls, 1, reason: '지급이 없으니 크레딧을 다시 읽지 않는다');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(find.text('새로운 일과 만들기'), findsOneWidget);
      expect(find.text('일과 입력'), findsNothing);
    }

    Future<void> watch(WidgetTester tester) async {
      await pumpHome(tester);
      await tapCreate(tester);
      await tester.tap(find.text(adButton));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    testWidgets('광고를 불러오지 못했다', (tester) async {
      loader.end = RewardedAdEnd.loadFailed;
      await watch(tester);
      await expectBackHome(tester, 'E-AD-LOAD');
    });

    testWidgets('광고를 끝까지 보지 않았다', (tester) async {
      loader.end = RewardedAdEnd.dismissed;
      await watch(tester);
      await expectBackHome(tester, 'E-AD-SKIP');
    });

    testWidgets('서버 확인이 늦다', (tester) async {
      adRepo.statuses = [_pending];
      await watch(tester);
      await expectBackHome(tester, 'E-AD-WAIT');
    });

    testWidgets('오늘 상한', (tester) async {
      adRepo.sessionError = AppFailure(
        fault: NetworkFault.none,
        server: ServerError(
          code: ServerErrorCode.adRewardDailyLimit,
          statusCode: 403,
        ),
      );
      await watch(tester);
      await expectBackHome(tester, 'AD_REWARD_DAILY_LIMIT');
      expect(loader.shownNonces, isEmpty);
    });

    testWidgets('멈춘 계정', (tester) async {
      adRepo.sessionError = AppFailure(
        fault: NetworkFault.none,
        server: ServerError(
          code: ServerErrorCode.adRewardAccountFrozen,
          statusCode: 403,
        ),
      );
      await watch(tester);
      await expectBackHome(tester, 'AD_REWARD_ACCOUNT_FROZEN');
    });

    testWidgets('오프라인', (tester) async {
      adRepo.sessionError = const AppFailure(fault: NetworkFault.offline);
      await watch(tester);
      await expectBackHome(tester, 'E-NET-OFFLINE');
    });

    testWidgets('서버가 지급하지 않기로 했다', (tester) async {
      adRepo.statuses = [
        const AdRewardSessionStatus(
          phase: AdRewardPhase.rejected,
          reason: 'DAILY_LIMIT',
        ),
      ];
      await watch(tester);
      await expectBackHome(tester, 'AD_REWARD_DAILY_LIMIT');
    });
  });
}

const _pending = AdRewardSessionStatus(phase: AdRewardPhase.pending);
const _granted = AdRewardSessionStatus(
  phase: AdRewardPhase.granted,
  grantedCredits: 2,
);

/// 서버가 정한 시점에야 상태를 돌려준다.
class _GatedRepo extends FakeAdRewardRepo {
  _GatedRepo(this.gate);

  final Completer<AdRewardSessionStatus> gate;

  @override
  Future<AdRewardSessionStatus> getStatus(String nonce) {
    statusCalls++;
    return gate.future;
  }
}

class _NoBanner implements AdBannerLoader {
  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) async => null;
}

/// 서버가 가진 잔액을 흉내 낸다. 읽은 횟수를 센다.
class _Credit extends CreditRepository {
  _Credit({this.available = 0, this.inProgress = const []}) : super(Dio());

  int available;
  final List<Object?> inProgress;
  var calls = 0;

  @override
  Future<CreditSummary> getMine() async {
    calls++;
    return CreditSummary.fromJson(
      creditJson(available: available, inProgress: inProgress),
    );
  }
}

class _HomeRepo with FakeRewardApi implements RoutineRepository {
  // 카드확인 카드 추가 (#444) — 이 테스트는 쓰지 않는다
  @override
  Future<({Routine routine, AppFailure? failure})> addStep(
    Routine routine, {
    required String title,
    required String description,
  }) async => (routine: routine, failure: null);
  @override
  Future<List<Routine>> getMyRoutines() async => const [];
  @override
  Future<List<Routine>> getTodayRoutines() async => const [];
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
