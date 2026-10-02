import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/credit/data/credit_repository.dart';
import 'package:elum/features/credit/domain/credit_summary.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/guardian/presentation/pin_change_screen.dart';
import 'package:elum/features/guardian/presentation/question_screen.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/domain/routine_stage.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/image_style_settings_screen.dart';
import 'package:elum/features/guardian/presentation/routine_loading_screen.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/credit_fixtures.dart';
import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/profile_fixtures.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';

/// 화면이 **어느 ARB 키를 읽는지**를 키 이름 표식으로 가려내는 가짜 번역.
///
/// 추출 작업은 한국어가 그대로여야 해서 기본값(ko)으로는 화면이 ARB 를 읽는지 리터럴이
/// 남아 있는지 구분되지 않는다. 모든 문구를 `⟦키⟧` 로 돌려주는 번역을 심으면, 화면에
/// 표식이 보이는 것이 곧 "그 자리가 그 키를 읽는다"는 증거다. 보간 인자는 괄호 안에 넣는다.
class _KeySpy implements AppLocalizations {
  /// 지금까지 화면이 읽은 키. 파일 끝의 점검이 이 목록으로 빠진 키를 가린다.
  static final seen = <String>{};

  @override
  String get localeName => 'ko';

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final raw = invocation.memberName.toString();
    final name = RegExp(r'"(.*)"').firstMatch(raw)!.group(1)!;
    seen.add(name);
    if (invocation.isGetter) return '⟦$name⟧';
    return '⟦$name(${invocation.positionalArguments.join(',')})⟧';
  }
}

class _SpyDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SpyDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(_KeySpy());

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

/// 표식 번역을 심은 앱으로 [routes] 를 띄운다. 화면 밖 층(`appL10n`)도 같은 번역을 읽는다.
Future<void> pumpSpy(
  WidgetTester tester, {
  required String initial,
  required List<RouteBase> routes,
  List<Object> overrides = const [],
}) async {
  setAppL10nForTest(_KeySpy());
  // 표식(`⟦키⟧`)은 실제 문구보다 길어 좁은 자리에서 넘칠 수 있다. 이 테스트는 어느 키를 읽는지만
  // 보므로 넘침은 무시한다 (실제 한국어 문구의 넘침은 각 화면의 기존 테스트가 지킨다).
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  await tester.pumpWidget(
    ProviderScope(
      // 실패한 로드를 스스로 다시 부르면 실패 화면을 볼 수 없다
      retry: (count, error) => null,
      overrides: overrides.cast(),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko')],
          localizationsDelegates: const [
            _SpyDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: GoRouter(initialLocation: initial, routes: routes),
        ),
      ),
    ),
  );
}

/// 배경이 무한 반복하는 화면이라 `pumpAndSettle` 을 쓸 수 없다.
Future<void> settle(WidgetTester tester, {int ms = 400}) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

/// 표식 하나가 화면에 정확히 한 번 있다.
void expectKey(String key, {bool semantics = false}) {
  final marker = '⟦$key⟧';
  expect(
    semantics ? find.bySemanticsLabel(marker) : find.text(marker),
    findsOneWidget,
    reason: '$key 를 읽는 자리가 없다',
  );
}

GoRoute _page(String path, Widget screen) =>
    GoRoute(path: path, builder: (context, state) => screen);

void main() {
  useFigmaViewport();

  // 표식 번역을 전역 통로에 남기지 않는다
  tearDown(setAppL10nForTest);

  group('보호자 홈', () {
    testWidgets('인사말·부제·구역 제목·아이콘 이름이 각자의 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        initial: Routes.guardian,
        routes: [_page(Routes.guardian, const GuardianHomeScreen())],
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          offlineDioOverride(),
        ],
      );
      await settle(tester);

      expect(find.text('⟦guardianHomeGreeting(하늘이)⟧'), findsOneWidget);
      expectKey('guardianHomeSubtitle');
      expectKey('guardianHomeTodayRoutine');
      expectKey('guardianHomePastRoutine');
      expectKey('guardianHomeGoChildScreen', semantics: true);
      expectKey('guardianHomeSettings', semantics: true);
      handle.dispose();
    });
  });

  group('그림 방식 설정', () {
    Future<void> pumpStyle(
      WidgetTester tester, {
      required Map<String, Object?> routes,
    }) => pumpSpy(
      tester,
      initial: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push(Routes.guardianImageStyle),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
        _page(Routes.guardianImageStyle, const ImageStyleSettingsScreen()),
      ],
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        fakeDioOverride(routes),
      ],
    );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('제목이 키를 읽는다', (tester) async {
      await pumpStyle(tester, routes: const {});
      await open(tester);
      expectKey('imageStyleTitle');
    });

    testWidgets('바꾸면 스낵바가 키를 읽는다', (tester) async {
      await pumpStyle(
        tester,
        routes: const {'PATCH /api/member/image-style': <String, Object?>{}},
      );
      await open(tester);
      await tester.tap(find.text('⟦imageStyleRealisticLabel⟧'));
      await tester.pumpAndSettle();
      expectKey('imageStyleChangedSnack');
    });

    testWidgets('저장에 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpStyle(tester, routes: const {});
      await open(tester);
      await tester.tap(find.text('⟦imageStyleRealisticLabel⟧'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('⟦imageStyleSaveFailedTitle⟧'),
        findsOneWidget,
      );
      expect(
        find.textContaining('⟦imageStyleSaveFailedFallback⟧'),
        findsOneWidget,
      );
    });
  });

  group('임시저장 목록', () {
    Routine draft(String id, String title) => Routine(
      id: id,
      title: title,
      status: 'PENDING_REVIEW',
      rawInputText: '',
      sanitizedInputText: '',
    );

    Future<void> pumpDrafts(
      WidgetTester tester, {
      List<Routine> list = const [],
      Object? error,
      AppFailure? deleteFailure,
    }) => pumpSpy(
      tester,
      initial: Routes.guardianDrafts,
      routes: [_page(Routes.guardianDrafts, const DraftRoutinesScreen())],
      overrides: [
        testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        routineRepositoryProvider.overrideWithValue(_DraftRepo(deleteFailure)),
        if (error == null)
          myRoutinesProvider.overrideWith((ref) async => list)
        else
          myRoutinesProvider.overrideWith((ref) async => throw error),
      ],
    );

    testWidgets('제목과 0건 안내가 키를 읽는다', (tester) async {
      await pumpDrafts(tester);
      await tester.pumpAndSettle();
      expectKey('draftRoutinesTitle');
      expectKey('draftRoutinesEmptyTitle');
      expectKey('draftRoutinesEmptyBody');
    });

    testWidgets('불러오지 못하면 기본 안내가 키를 읽는다', (tester) async {
      await pumpDrafts(tester, error: StateError('서버가 응답하지 않음'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('⟦draftRoutinesLoadFailedFallback⟧'),
        findsWidgets,
      );
    });

    testWidgets('보상 있는 줄과 없는 줄의 말머리·값·이어서·삭제 이름이 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpDrafts(
        tester,
        list: [
          draft('1', '아침 준비'),
          draft('2', '저녁 준비').copyWith(rewardText: '젤리'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('⟦draftRoutinesRewardLabel⟧'), findsNWidgets(2));
      expect(find.text('⟦draftRoutinesResume⟧'), findsNWidgets(2));
      // 보상을 정하지 않은 줄만 미설정이다
      expect(find.text('⟦draftRoutinesRewardUnset⟧'), findsOneWidget);
      expect(find.text('젤리'), findsOneWidget);
      // 줄마다 삭제 버튼이 깔려 있다 (밀기 전에도 의미 이름은 있다)
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '⟦draftRoutinesDeleteLabel⟧',
        ),
        findsNWidgets(2),
      );
      handle.dispose();
    });

    Future<void> openDeleteDialog(WidgetTester tester) async {
      await tester.drag(find.text('저녁 준비'), const Offset(-80, 0));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  w.properties.label == '⟦draftRoutinesDeleteLabel⟧',
            )
            .last,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('삭제 확인 팝업의 제목·취소·삭제가 키를 읽는다', (tester) async {
      await pumpDrafts(
        tester,
        list: [draft('1', '아침 준비'), draft('2', '저녁 준비')],
      );
      await tester.pumpAndSettle();
      await openDeleteDialog(tester);

      expectKey('draftRoutinesDeleteConfirmTitle');
      expectKey('commonCancel');
      expectKey('draftRoutinesDeleteAction');
    });

    testWidgets('삭제에 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpDrafts(
        tester,
        list: [draft('1', '아침 준비'), draft('2', '저녁 준비')],
        deleteFailure: const AppFailure(fault: NetworkFault.app),
      );
      await tester.pumpAndSettle();
      await openDeleteDialog(tester);
      await tester.tap(find.text('⟦draftRoutinesDeleteAction⟧'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('⟦draftRoutinesDeleteFailedTitle⟧'),
        findsOneWidget,
      );
      expect(
        find.textContaining('⟦draftRoutinesDeleteFailedFallback⟧'),
        findsOneWidget,
      );
    });
  });

  group('보호자 설정', () {
    late _FakeAuth auth;
    setUp(() => auth = _FakeAuth());

    Future<void> pumpSettings(
      WidgetTester tester, {
      Attempt<LinkStatus>? link,
      int profiles = 1,
    }) => pumpSpy(
      tester,
      initial: Routes.guardianSettings,
      routes: [
        _page(Routes.guardianSettings, const GuardianSettingsScreen()),
        _page(Routes.login, const Scaffold(body: Text('로그인 화면'))),
      ],
      overrides: [
        testStorageOverride(onboardingCompleted: true),
        authRepositoryProvider.overrideWithValue(auth),
        memberProvider.overrideWith(
          (ref) async => memberWith([kProfileA, if (profiles > 1) kProfileB]),
        ),
        consentBundleProvider.overrideWith(
          (ref) async => ConsentBundle.bundled,
        ),
        appVersionProvider.overrideWith((ref) async => '1.0.0'),
        creditSummaryProvider.overrideWith(
          (ref) async => CreditSummary.fromJson(creditJson(enabled: false)),
        ),
        linkStatusProvider.overrideWith(
          (ref) async => link ?? Attempt.ok(LinkStatus.empty),
        ),
      ],
    );

    testWidgets('제목과 줄 이름이 각자의 키를 읽는다 (연결 전)', (tester) async {
      await pumpSettings(tester, profiles: 2);
      await tester.pumpAndSettle();

      for (final key in [
        'guardianSettingsTitle',
        'guardianSettingsLinkConnect',
        'guardianSettingsPeople',
        'guardianSettingsDrafts',
        'guardianSettingsPinChange',
        'guardianSettingsImageStyle',
        'guardianSettingsHaptic',
        'guardianSettingsTerms',
        'guardianSettingsLogout',
        'guardianSettingsWithdraw',
        'guardianSettingsProfileSwitch',
      ]) {
        expectKey(key);
      }
      expect(find.text('⟦guardianSettingsLinkStatus⟧'), findsNothing);
    });

    testWidgets('이룸이 휴대폰이 연결되면 줄 이름과 상태 값이 다른 키를 읽는다', (tester) async {
      await pumpSettings(
        tester,
        link: Attempt.ok(
          LinkStatus(
            devices: [
              LinkedDevice(linkId: 'l1', linkedAt: DateTime(2026, 9, 18)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectKey('guardianSettingsLinkConnected');
      expectKey('guardianSettingsLinkStatus');
      expect(find.text('⟦guardianSettingsLinkConnect⟧'), findsNothing);
    });

    testWidgets('로그아웃 확인 팝업의 제목·취소·확인이 키를 읽는다', (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('⟦guardianSettingsLogout⟧'));
      await tester.pumpAndSettle();

      expectKey('guardianSettingsLogoutConfirmTitle');
      expectKey('commonCancel');
      expectKey('commonConfirm');
    });

    testWidgets('회원탈퇴 확인 팝업과 실패 팝업이 키를 읽는다', (tester) async {
      auth.deleteSucceeds = false;
      await pumpSettings(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('⟦guardianSettingsWithdraw⟧'));
      await tester.pumpAndSettle();

      expectKey('guardianSettingsWithdrawConfirmTitle');
      expectKey('guardianSettingsWithdrawConfirmMessage');

      await tester.tap(find.text('⟦commonConfirm⟧'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('⟦guardianSettingsWithdrawFailedTitle⟧'),
        findsOneWidget,
      );
      expect(
        find.textContaining('⟦guardianSettingsWithdrawFailedFallback⟧'),
        findsOneWidget,
      );
    });
  });

  group('비밀암호 변경', () {
    Future<void> pumpPin(
      WidgetTester tester, {
      bool createOnly = false,
      String? pin = '1234',
      LocalStorage? storage,
    }) => pumpSpy(
      tester,
      initial: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.push('/pin'),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/pin',
          builder: (context, state) => PinChangeScreen(createOnly: createOnly),
        ),
        _page(Routes.guardian, const Scaffold(body: Text('보호자 홈'))),
      ],
      overrides: [
        localStorageProvider.overrideWithValue(
          storage ?? InMemoryStorage(onboardingCompleted: true, pin: pin),
        ),
      ],
    );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    Future<void> enter(WidgetTester tester, String pin) async {
      await tester.enterText(find.byType(TextField), pin);
      await tester.pumpAndSettle();
    }

    testWidgets('바꾸기 — 지금 암호 단계 제목·머리·입력 이름·틀림 안내가 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPin(tester);
      await open(tester);

      expectKey('pinChangeVerifyTitle');
      expectKey('pinChangeHeaderTitle');
      expectKey('pinChangeInputLabel', semantics: true);
      // 시안은 이 단계에 설명이 없다
      expect(find.text('⟦pinModeHint⟧'), findsNothing);

      await enter(tester, '9999');
      expectKey('pinChangeMismatch');
      expect(find.text('⟦pinChangeMismatchCreate⟧'), findsNothing);
      handle.dispose();
    });

    testWidgets('바꾸기 — 새 암호·한번 더 단계와 저장 버튼·스낵바가 키를 읽는다', (tester) async {
      await pumpPin(tester);
      await open(tester);
      await enter(tester, '1234');

      expectKey('pinChangeEnterTitle');
      expectKey('pinModeHint');

      await enter(tester, '5678');
      expectKey('pinChangeConfirmTitle');
      expectKey('pinChangeConfirmHint');

      await enter(tester, '5678');
      expectKey('pinChangeSave');
      await tester.tap(find.text('⟦pinChangeSave⟧'));
      await tester.pumpAndSettle();
      expectKey('pinChangeChangedSnack');
    });

    testWidgets('바꾸기 — 저장이 안 되면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpPin(tester, storage: _BrokenPinStorage());
      await open(tester);
      await enter(tester, '1234');
      await enter(tester, '5678');
      await enter(tester, '5678');
      await tester.tap(find.text('⟦pinChangeSave⟧'));
      await tester.pumpAndSettle();

      expect(find.textContaining('⟦pinChangeFailedTitle⟧'), findsOneWidget);
      expect(find.textContaining('⟦pinChangeFailedFallback⟧'), findsOneWidget);
    });

    testWidgets('만들기 — 제목·설명·재입력·틀림 안내·스낵바가 만들기 키를 읽는다', (tester) async {
      await pumpPin(tester, createOnly: true, pin: null);
      await open(tester);

      expectKey('pinChangeCreateTitle');
      expectKey('pinModeHint');
      // 만들기는 온보딩 머리 그대로다 — 바꾸기 머리 제목이 없다
      expect(find.text('⟦pinChangeHeaderTitle⟧'), findsNothing);

      await enter(tester, '5678');
      expectKey('pinChangeCreateConfirmTitle');
      expectKey('pinModeHint');

      await enter(tester, '0000');
      expectKey('pinChangeMismatchCreate');
      expect(find.text('⟦pinChangeMismatch⟧'), findsNothing);

      await enter(tester, '5678');
      await tester.tap(find.text('⟦pinChangeSave⟧'));
      await tester.pumpAndSettle();
      expectKey('pinChangeCreatedSnack');
    });

    testWidgets('만들기 — 저장이 안 되면 만들기 실패 제목을 읽는다', (tester) async {
      await pumpPin(
        tester,
        createOnly: true,
        storage: _BrokenPinStorage(pin: null),
      );
      await open(tester);
      await enter(tester, '5678');
      await enter(tester, '5678');
      await tester.tap(find.text('⟦pinChangeSave⟧'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('⟦pinChangeCreateFailedTitle⟧'),
        findsOneWidget,
      );
    });
  });

  group('보상 정하기', () {
    Future<void> pumpReward(WidgetTester tester, {bool fromReview = false}) =>
        pumpSpy(
          tester,
          initial: Routes.routineReward,
          routes: [
            _page(
              Routes.routineReward,
              RewardSetupScreen(fromReview: fromReview),
            ),
          ],
          overrides: [
            testStorageOverride(nickname: '하늘이'),
            offlineDioOverride(),
          ],
        );

    testWidgets('제목·부제·다음·도움말·나중에가 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReward(tester);
      await settle(tester);

      expectKey('rewardHeadlineTitle');
      expectKey('rewardHeadlineBody');
      expectKey('commonNext');
      expectKey('rewardWhyTitle'); // 도움말 링크 글
      expectKey('rewardLater');
      expectKey('rewardWhyTitle', semantics: true);
      handle.dispose();
    });

    testWidgets('도움말을 누르면 팝업 제목·본문이 키를 읽고 정적 getter 도 같은 키다', (tester) async {
      await pumpReward(tester);
      await settle(tester);
      await tester.tap(find.text('⟦rewardWhyTitle⟧'));
      await settle(tester);

      // 링크 글과 팝업 제목 두 곳이다
      expect(find.text('⟦rewardWhyTitle⟧'), findsNWidgets(2));
      expect(RewardSetupScreen.whyMessage, '⟦rewardWhyMessage⟧');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data == '⟦rewardWhyMessage⟧' ||
                  w.semanticsLabel == '⟦rewardWhyMessage⟧'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('카드 검토에서 고치다 저장에 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpReward(tester, fromReview: true);
      await settle(tester);
      await tester.enterText(find.byType(TextField), '공원 가기');
      await settle(tester);
      // 고칠 일과가 없는 상태라 저장은 실패로 돌아온다
      await tester.tap(find.text('⟦commonNext⟧'));
      await settle(tester);

      expect(find.textContaining('⟦rewardSaveFailedTitle⟧'), findsOneWidget);
      expect(find.textContaining('⟦rewardSaveFailedFallback⟧'), findsOneWidget);
    });
  });

  group('일과 입력', () {
    testWidgets('제목·부제·안내 글·보내기 이름이 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSpy(
        tester,
        initial: Routes.routineInput,
        routes: [_page(Routes.routineInput, const RoutineInputScreen())],
        overrides: [
          testStorageOverride(onboardingCompleted: true),
          routineSuggestionsProvider.overrideWith(
            (ref) async => RoutineSuggestion.fallback,
          ),
        ],
      );
      await settle(tester);

      expectKey('routineInputTitle');
      expectKey('routineInputSubtitle');
      expectKey('routineInputHint');
      // 입력이 있어야 보내기가 나타난다
      expect(find.bySemanticsLabel('⟦routineInputSend⟧'), findsNothing);
      await tester.enterText(find.byType(TextField), '수영장 가기');
      await settle(tester);
      expectKey('routineInputSend', semantics: true);
      handle.dispose();
    });
  });

  group('추가 질문', () {
    const question = RoutineQuestion(
      isRequired: true,
      questions: [
        QuestionItem(
          question: '꼭 챙겨야 하는 준비물이 있나요?',
          options: [
            QuestionOption(label: '우산'),
            QuestionOption(label: '장화'),
          ],
        ),
      ],
    );

    testWidgets('직접 입력 칩·칸 안내·닫기·지우기·카드 만들기가 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      final container = ProviderContainer(
        overrides: [
          testStorageOverride(onboardingCompleted: true),
          offlineDioOverride(),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(routineFlowProvider.notifier)
          .state = const RoutineFlowState(
        question: question,
        answers: ['진료카드'],
        customOptions: {
          '꼭 챙겨야 하는 준비물이 있나요?': ['진료카드'],
        },
      );
      setAppL10nForTest(_KeySpy());
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              locale: const Locale('ko'),
              supportedLocales: const [Locale('ko')],
              localizationsDelegates: const [
                _SpyDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: GoRouter(
                initialLocation: Routes.routineQuestion,
                routes: [_page(Routes.routineQuestion, const QuestionScreen())],
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      // 답이 있어 카드 만들기가 나타난다
      expectKey('questionMakeCards');
      expectKey('questionCustomAdd');
      // 직접 적은 칩의 X 는 칩 글자를 인자로 넘겨 읽는다
      expect(
        find.bySemanticsLabel('⟦questionClearLabel(진료카드)⟧'),
        findsOneWidget,
      );

      await tester.tap(find.text('⟦questionCustomAdd⟧'));
      await settle(tester);
      expectKey('questionCustomHint');
      expectKey('questionCustomClose', semantics: true);
      handle.dispose();
    });
  });

  group('카드 검토', () {
    const cards = [
      ActionCard(id: 'c1', stepOrder: 1, title: '옷을 입어요', description: '옷 설명'),
      ActionCard(
        id: 'c2',
        stepOrder: 2,
        title: '가방을 챙겨요',
        description: '가방 설명',
      ),
    ];

    Future<ProviderContainer> pumpReview(
      WidgetTester tester, {
      bool soundFails = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          // 등록하지 않은 경로는 404 라서 저장·수정·추가가 모두 실패로 돌아온다
          offlineDioOverride(),
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          speechServiceProvider.overrideWithValue(_Speech(ok: !soundFails)),
        ],
      );
      addTearDown(container.dispose);
      container.read(routineFlowProvider.notifier).state = RoutineFlowState(
        routine: const Routine(
          id: 'r1',
          title: '학교에 가요',
          status: 'PENDING_REVIEW',
          steps: cards,
        ),
      );
      setAppL10nForTest(_KeySpy());
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              locale: const Locale('ko'),
              supportedLocales: const [Locale('ko')],
              localizationsDelegates: const [
                _SpyDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: GoRouter(
                initialLocation: Routes.routineReview,
                routes: [
                  _page(Routes.routineReview, const CardReviewScreen()),
                  _page(Routes.guardian, const Scaffold(body: Text('홈'))),
                ],
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      return container;
    }

    testWidgets('하단 버튼은 저장하기, 순서 바꾸기 중에는 완료 키를 읽는다', (tester) async {
      await pumpReview(tester);
      expectKey('cardReviewSave');
      expect(find.text('⟦cardReviewReorderDone⟧'), findsNothing);

      await tester.tap(find.text('카드 순서 변경'));
      await settle(tester);
      expectKey('cardReviewReorderDone');
      expect(find.text('⟦cardReviewSave⟧'), findsNothing);
    });

    testWidgets('카드 지우기 확인 팝업의 제목·취소·삭제가 키를 읽는다', (tester) async {
      await pumpReview(tester);
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is AppPressable && w.semanticLabel == '이 카드 지우기',
            )
            .first,
      );
      await settle(tester);

      expectKey('cardReviewDeleteConfirmTitle');
      expectKey('commonCancel');
      expectKey('cardReviewDeleteAction');
    });

    testWidgets('저장에 실패하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.text('⟦cardReviewSave⟧'));
      await settle(tester);

      expect(
        find.textContaining('⟦cardReviewSaveFailedTitle⟧'),
        findsOneWidget,
      );
      expect(
        find.textContaining('⟦cardReviewSaveFailedFallback⟧'),
        findsOneWidget,
      );
    });

    testWidgets('소리를 못 내면 실패 제목·안내가 키를 읽는다', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReview(tester, soundFails: true);
      await tester.tap(find.bySemanticsLabel('소리로 듣기').first);
      await settle(tester);

      expect(
        find.textContaining('⟦cardReviewSoundFailedTitle⟧'),
        findsOneWidget,
      );
      expect(
        find.textContaining('⟦cardReviewSoundFailedFallback⟧'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('카드를 고치다 서버가 거절하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.text('이 카드 수정'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '가방을 싸요');
      await tester.enterText(find.byType(TextField).last, '책을 넣어요');
      await tester.tap(find.text('완료').last);
      await settle(tester);

      expect(
        find.textContaining('⟦cardReviewEditFailedTitle⟧'),
        findsOneWidget,
      );
      expect(
        find.textContaining('⟦cardReviewEditFailedFallback⟧'),
        findsOneWidget,
      );
    });

    testWidgets('카드를 추가하다 서버가 거절하면 실패 제목·기본 안내가 키를 읽는다', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.text('카드 추가'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, '양치를 해요');
      await tester.enterText(find.byType(TextField).last, '이를 닦아요');
      await tester.pump();
      await tester.tap(find.text('추가하기'));
      await settle(tester);

      expect(find.textContaining('⟦cardReviewAddFailedTitle⟧'), findsOneWidget);
      expect(
        find.textContaining('⟦cardReviewAddFailedFallback⟧'),
        findsOneWidget,
      );
    });
  });

  group('일과 로딩 실패 화면', () {
    Future<void> pumpFailure(
      WidgetTester tester,
      RoutineLoadingKind kind,
      Object? serverResponse,
    ) async {
      await pumpSpy(
        tester,
        initial: '/loading',
        routes: [_page('/loading', RoutineLoadingScreen(kind: kind))],
        overrides: [
          fakeDioOverride({
            'POST /api/routines/questions': ?serverResponse,
            'POST /api/routines': ?serverResponse,
          }),
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        ],
      );
      // 로딩 연출을 지나 실패가 드러날 때까지 민다
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('준비 로딩이 서버에 못 닿으면 제목·다시 하기가 키를 읽는다', (tester) async {
      await pumpFailure(
        tester,
        RoutineLoadingKind.prepare,
        const FakeOffline(),
      );
      expectKey('routineLoadingPrepareFailed');
      expectKey('routineLoadingRetry');
      // 오프라인 힌트는 AppFailure 가 현재 번역으로 푼다
      expect(find.text('⟦failureHintOffline⟧'), findsOneWidget);
      expect(find.text('⟦commonRetryLater⟧'), findsNothing);
    });

    testWidgets('생성 로딩이 서버 문구 없이 실패하면 제목과 기본 안내가 키를 읽는다', (tester) async {
      await pumpFailure(tester, RoutineLoadingKind.generate, null);
      expectKey('routineLoadingGenerateFailed');
      expectKey('commonRetryLater');
      expectKey('routineLoadingRetry');
    });

    testWidgets('크레딧 때문에 막히면 막힘 제목과 홈으로가 키를 읽는다', (tester) async {
      await pumpFailure(
        tester,
        RoutineLoadingKind.generate,
        const FakeHttpError(
          403,
          errorCode: 'AI_CREDIT_INSUFFICIENT',
          errorMessage: '서버가 준 이유',
        ),
      );
      expectKey('routineLoadingBlockedTitle');
      expectKey('routineLoadingHome');
      // 서버 문구가 기본 문구를 이긴다
      expect(find.text('서버가 준 이유'), findsOneWidget);
      expect(find.text('⟦routineLoadingRetry⟧'), findsNothing);
    });

    testWidgets('진행률은 숫자를 인자로 넘겨 읽는다', (tester) async {
      await pumpSpy(
        tester,
        initial: '/loading',
        routes: [
          _page(
            '/loading',
            const RoutineLoadingScreen(kind: RoutineLoadingKind.prepare),
          ),
        ],
        overrides: [
          fakeDioOverride(const {}, delay: const Duration(seconds: 30)),
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
        ],
      );
      await settle(tester, ms: 450);
      expect(
        find.textContaining(RegExp(r'^⟦routineLoadingPercent\(\d+\)⟧$')),
        findsOneWidget,
      );
      // 끝까지 흘려보낸다 (남은 타이머 정리)
      await tester.pump(const Duration(seconds: 40));
      await settle(tester);
    });
  });

  group('한국어 값 — 표식 없이 실제 ARB 로 그린 결과', () {
    Future<void> pumpKoLoading(
      WidgetTester tester,
      RoutineLoadingKind kind,
      Object? serverResponse,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (count, error) => null,
          overrides: [
            fakeDioOverride({
              'POST /api/routines/questions': ?serverResponse,
              'POST /api/routines': ?serverResponse,
            }),
            testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: GoRouter(
                initialLocation: '/loading',
                routes: [_page('/loading', RoutineLoadingScreen(kind: kind))],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('준비 로딩 실패 — 제목·네트워크 힌트·다시 하기', (tester) async {
      await pumpKoLoading(
        tester,
        RoutineLoadingKind.prepare,
        const FakeOffline(),
      );
      expect(find.text('질문을 준비하지 못했어요'), findsOneWidget);
      expect(find.text('인터넷 연결을 확인해주세요'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);
      expect(find.text('홈으로'), findsNothing);
    });

    testWidgets('생성 로딩 실패 — 제목·기본 안내·다시 하기', (tester) async {
      await pumpKoLoading(tester, RoutineLoadingKind.generate, null);
      expect(find.text('카드를 만들지 못했어요'), findsOneWidget);
      expect(find.text('잠시 후 다시 해주세요'), findsOneWidget);
      expect(find.text('다시 하기'), findsOneWidget);
    });

    testWidgets('크레딧으로 막힘 — 막힘 제목·서버 문구·홈으로', (tester) async {
      await pumpKoLoading(
        tester,
        RoutineLoadingKind.generate,
        const FakeHttpError(
          403,
          errorCode: 'AI_CREDIT_INSUFFICIENT',
          errorMessage: '이번 주 크레딧을 다 썼어요',
        ),
      );
      expect(find.text('지금은 만들 수 없어요'), findsOneWidget);
      expect(find.text('이번 주 크레딧을 다 썼어요'), findsOneWidget);
      expect(find.text('홈으로'), findsOneWidget);
      expect(find.text('다시 하기'), findsNothing);
    });

    testWidgets('진행률은 숫자와 함께 한국어 문장이다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fakeDioOverride(const {}, delay: const Duration(seconds: 30)),
            testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, _) => MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: GoRouter(
                initialLocation: '/loading',
                routes: [
                  _page(
                    '/loading',
                    const RoutineLoadingScreen(
                      kind: RoutineLoadingKind.prepare,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.textContaining(RegExp(r'^\d+% 진행됐어요$')), findsOneWidget);
      await tester.pump(const Duration(seconds: 40));
      await tester.pump();
    });

    testWidgets('번역이 없는 언어(ja)로 띄우면 ko 문구로 떨어진다', (tester) async {
      await pumpWithLocale(
        tester,
        const ImageStyleSettingsScreen(),
        locale: const Locale('ja'),
        wrap: (app) => ProviderScope(
          overrides: [testStorageOverride(onboardingCompleted: true)],
          child: app,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      // ARB 가 비어 있는 언어는 ko 값으로 대체한다 (번역은 하위 계획 5)
      expect(find.text('그림 방식'), findsOneWidget);
    });
  });

  // 이 파일의 마지막 시험이다 (같은 파일의 시험은 선언 순서로 돈다).
  test('이 폴더에서 새로 만든 키 91개를 화면이 모두 읽었다', () {
    const expected = <String>{
      'guardianHomeTodayRoutine',
      'guardianHomePastRoutine',
      'guardianHomeGoChildScreen',
      'guardianHomeSettings',
      'guardianHomeGreeting',
      'guardianHomeSubtitle',
      'pinChangeMismatchCreate',
      'pinChangeMismatch',
      'pinChangeCreateFailedTitle',
      'pinChangeFailedTitle',
      'pinChangeFailedFallback',
      'pinChangeCreatedSnack',
      'pinChangeChangedSnack',
      'pinChangeVerifyTitle',
      'pinChangeCreateTitle',
      'pinModeHint',
      'pinChangeEnterTitle',
      'pinChangeCreateConfirmTitle',
      'pinChangeConfirmTitle',
      'pinChangeConfirmHint',
      'pinChangeHeaderTitle',
      'pinChangeSave',
      'pinChangeInputLabel',
      'rewardSaveFailedTitle',
      'rewardSaveFailedFallback',
      'rewardWhyTitle',
      'rewardWhyMessage',
      'rewardHeadlineTitle',
      'rewardHeadlineBody',
      'rewardLater',
      'imageStyleChangedSnack',
      'imageStyleSaveFailedTitle',
      'imageStyleSaveFailedFallback',
      'imageStyleTitle',
      'routineLoadingBlockedTitle',
      'routineLoadingPrepareFailed',
      'routineLoadingGenerateFailed',
      'routineLoadingPercent',
      'routineLoadingRetry',
      'routineLoadingHome',
      'draftRoutinesTitle',
      'draftRoutinesLoadFailedFallback',
      'draftRoutinesDeleteLabel',
      'draftRoutinesDeleteConfirmTitle',
      'draftRoutinesDeleteAction',
      'draftRoutinesDeleteFailedTitle',
      'draftRoutinesDeleteFailedFallback',
      'draftRoutinesRewardUnset',
      'draftRoutinesRewardLabel',
      'draftRoutinesResume',
      'draftRoutinesEmptyTitle',
      'draftRoutinesEmptyBody',
      'cardReviewDeleteConfirmTitle',
      'cardReviewDeleteAction',
      'cardReviewSoundFailedTitle',
      'cardReviewSoundFailedFallback',
      'cardReviewSaveFailedTitle',
      'cardReviewSaveFailedFallback',
      'cardReviewEditFailedTitle',
      'cardReviewEditFailedFallback',
      'cardReviewAddFailedTitle',
      'cardReviewAddFailedFallback',
      'cardReviewReorderDone',
      'cardReviewSave',
      'routineInputTitle',
      'routineInputSubtitle',
      'routineInputHint',
      'routineInputSend',
      'guardianSettingsLogoutConfirmTitle',
      'guardianSettingsWithdrawConfirmTitle',
      'guardianSettingsWithdrawConfirmMessage',
      'guardianSettingsWithdrawFailedTitle',
      'guardianSettingsWithdrawFailedFallback',
      'guardianSettingsTitle',
      'guardianSettingsPeople',
      'guardianSettingsDrafts',
      'guardianSettingsPinChange',
      'guardianSettingsTerms',
      'guardianSettingsLogout',
      'guardianSettingsWithdraw',
      'guardianSettingsLinkConnected',
      'guardianSettingsLinkConnect',
      'guardianSettingsLinkStatus',
      'guardianSettingsProfileSwitch',
      'guardianSettingsImageStyle',
      'guardianSettingsHaptic',
      'questionMakeCards',
      'questionCustomAdd',
      'questionCustomHint',
      'questionCustomClose',
      'questionClearLabel',
    };
    expect(
      expected.difference(_KeySpy.seen),
      isEmpty,
      reason: '화면이 읽지 않은 키가 있다 — 연결이 끊겼거나 시험이 그 자리를 안 밟는다',
    );
  });
}

class _DraftRepo implements RoutineRepository {
  _DraftRepo(this.failure);

  final AppFailure? failure;

  @override
  Future<AppFailure?> delete(String routineId) async => failure;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends AuthRepository {
  _FakeAuth()
    : super(
        dio: Dio(),
        storage: InMemoryStorage(),
        tokens: InMemoryTokenStore(),
        sdk: OAuthSdk(),
      );

  /// 서버 삭제가 실패하는 상황을 만들 때 false 로 둔다
  bool deleteSucceeds = true;

  @override
  Future<void> logout() async {}

  @override
  Future<AppFailure?> deleteAccount() async =>
      deleteSucceeds ? null : const AppFailure(fault: NetworkFault.app);
}

class _BrokenPinStorage extends InMemoryStorage {
  _BrokenPinStorage({super.pin = '1234'}) : super(onboardingCompleted: true);

  /// 쓰기가 조용히 실패한다 — 화면은 다시 읽어 봐야 안다
  @override
  Future<void> setPin(String v) async {}
}

class _Speech implements SpeechService {
  _Speech({required this.ok});

  final bool ok;

  @override
  Future<bool> speak(String text) async => ok;

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
