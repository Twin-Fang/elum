import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/child/presentation/widgets/reward_banner.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/card_review_screen.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_summary_tile.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/fake_reward_api.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';

/// 일과 글(카드 제목·설명·일과 제목·보상)은 **일과 언어**, 화면 문구는 **휴대폰 언어**다.
/// 각 시험은 두 언어를 서로 다른 값으로 두고, 글자 스타일 locale 과 `Localizations` 를 값으로 맞댄다.
void main() {
  useFigmaViewport();
  tearDown(setAppL10nForTest);

  const ja = Locale('ja');

  Locale? styleLocale(WidgetTester tester, Finder f) =>
      DefaultTextStyle.of(tester.element(f)).style.locale;

  /// 카드 안의 제목 글자. 그림이 없으면 제목이 그림 자리의 글로 그려진다.
  Finder cardTitle(String title) => find.byWidgetPredicate(
    (w) =>
        w is Text &&
        (w.data?.replaceAll('\u2060', '') == title ||
            w.semanticsLabel == title),
  );

  const jaCards = [
    ActionCard(
      id: 'c1',
      title: '服を着ます',
      description: '学校に行く服を着ます',
      stepOrder: 1,
    ),
    ActionCard(
      id: 'c2',
      title: '靴をはきます',
      description: '玄関で靴をはきます',
      stepOrder: 2,
    ),
  ];
  const jaRoutine = Routine(
    id: 'r1',
    title: '学校へ行く',
    status: 'CONFIRMED',
    steps: jaCards,
    rewardText: 'ゼリーを食べる',
    language: 'ja',
  );

  final spoken = <String>[];
  final languages = <String>[];
  setUp(() {
    spoken.clear();
    languages.clear();
  });

  group('보호자 일과 상세 시트·카드 크게 보기', () {
    Future<void> pumpSheet(WidgetTester tester, Routine routine) async {
      await pumpWithLocale(
        tester,
        Scaffold(body: RoutineDetailSheet(routine: routine)),
        locale: const Locale('en'),
        wrap: (app) => ProviderScope(
          overrides: [
            offlineDioOverride(),
            testStorageOverride(onboardingCompleted: true),
            routineRepositoryProvider.overrideWithValue(_Repo()),
            speechServiceProvider.overrideWithValue(_Speech(spoken, languages)),
          ],
          child: app,
        ),
      );
      await tester.pump();
    }

    testWidgets('단계 줄·보상·시트 제목은 일과 언어, 화면 언어는 en', (tester) async {
      await pumpSheet(tester, jaRoutine);

      for (final text in ['服を着ます', '学校に行く服を着ます', 'ゼリーを食べる', '学校へ行く']) {
        final f = find.text(text);
        expect(f, findsOneWidget, reason: text);
        expect(styleLocale(tester, f), ja, reason: '$text 는 일과 언어');
        expect(Localizations.localeOf(tester.element(f)), const Locale('en'));
        expect(tester.element(f).l10n.localeName, 'en');
      }
    });

    testWidgets('보상이 없을 때 안내는 화면 문구라 일과 언어를 입지 않는다', (tester) async {
      await pumpSheet(tester, jaRoutine.copyWith(rewardText: ''));

      final f = find.text(
        tester
            .element(find.byType(RoutineDetailSheet))
            .l10n
            .routineDetailNoReward,
      );
      expect(f, findsOneWidget);
      expect(styleLocale(tester, f), isNot(ja));
    });

    testWidgets('카드를 크게 열어 읽으면 일과 언어로 읽고 글도 일과 언어다', (tester) async {
      await pumpSheet(tester, jaRoutine);

      // 시트 줄의 제목을 눌러 크게 연다
      await tester.tap(find.text('靴をはきます'));
      await tester.pumpAndSettle();

      final view = tester
          .widgetList<ActionCardView>(find.byType(ActionCardView))
          .firstWhere((v) => v.card.id == 'c2');
      expect(view.language, 'ja');
      view.onSpeak!();
      await tester.pump();
      expect(languages, ['ja']);

      // 큰 카드 안의 글도 일과 언어
      final bigTitle = find.descendant(
        of: find.byType(ActionCardView),
        matching: cardTitle('靴をはきます'),
      );
      expect(bigTitle, findsWidgets);
      expect(styleLocale(tester, bigTitle.first), ja);
      expect(
        Localizations.localeOf(tester.element(bigTitle.first)),
        const Locale('en'),
      );
    });
  });

  group('보호자 카드 확인 화면', () {
    Future<void> pumpReview(WidgetTester tester) =>
        _pumpReview(tester, jaRoutine, spoken, languages);

    testWidgets('카드 글은 일과 언어, 읽을 때도 일과 언어', (tester) async {
      await pumpReview(tester);

      final view = tester
          .widgetList<ActionCardView>(find.byType(ActionCardView))
          .firstWhere((v) => v.card.id == 'c1');
      expect(view.language, 'ja');
      view.onSpeak!();
      await tester.pump();
      expect(spoken, ['服を着ます. 学校に行く服を着ます']);
      expect(languages, ['ja']);

      final title = cardTitle('服を着ます');
      expect(styleLocale(tester, title.first), ja);
      expect(
        Localizations.localeOf(tester.element(title.first)),
        const Locale('ko'),
      );
    });

    testWidgets('순서 바꾸기 목록의 카드도 일과 언어로 그린다', (tester) async {
      await pumpReview(tester);
      await tester.tap(find.text('카드 순서 변경'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final views = tester
          .widgetList<ActionCardView>(find.byType(ActionCardView))
          .toList();
      expect(views, isNotEmpty);
      expect(views.map((v) => v.language).toSet(), {'ja'});
      final title = cardTitle('服を着ます');
      expect(title, findsWidgets);
      expect(styleLocale(tester, title.first), ja);
    });
  });

  group('순서 바꾸기에서 끌려 올라온 카드', () {
    testWidgets('손가락을 따라다니는 카드도 일과 언어로 그린다', (tester) async {
      await _pumpReview(tester, jaRoutine, spoken, languages);
      await tester.tap(find.text('카드 순서 변경'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('c1'))),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 50));

      final views = tester
          .widgetList<ActionCardView>(find.byType(ActionCardView))
          .toList();
      // 끌려 올라온 사본(그림자를 두른 카드)도 일과 언어여야 한다
      expect(views.map((v) => v.language).toSet(), {'ja'});
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('이룸이 화면', () {
    Future<void> pumpChild(
      WidgetTester tester,
      Widget screen, {
      Locale locale = const Locale('en'),
      List<Routine> today = const [],
    }) async {
      await pumpWithLocale(
        tester,
        screen,
        locale: locale,
        wrap: (app) => ProviderScope(
          overrides: [
            offlineDioOverride(),
            testStorageOverride(onboardingCompleted: true),
            speechServiceProvider.overrideWithValue(_Speech(spoken, languages)),
            myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
            todayRoutinesProvider.overrideWith((ref) async => today),
            memberProvider.overrideWith(
              (ref) async => const Member(nickname: '민준'),
            ),
          ],
          child: app,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('이룸이 홈의 일과 제목은 일과 언어, 다하면 문구는 화면 언어', (tester) async {
      await pumpChild(tester, const ChildHomeScreen(), today: [jaRoutine]);

      final title = find.text('学校へ行く');
      expect(title, findsOneWidget);
      expect(styleLocale(tester, title), ja);
      expect(Localizations.localeOf(tester.element(title)), const Locale('en'));

      final prefix = find.text(
        tester.element(title).l10n.childHomeRewardPrefix,
      );
      expect(prefix, findsOneWidget);
      expect(styleLocale(tester, prefix), isNot(ja));
    });

    testWidgets('일과 상세 상단 제목은 일과 언어', (tester) async {
      await pumpChild(tester, ChildRoutineDetailScreen(routine: jaRoutine));

      final title = find.text('学校へ行く');
      expect(title, findsOneWidget);
      expect(styleLocale(tester, title), ja);
      expect(Localizations.localeOf(tester.element(title)), const Locale('en'));
    });

    testWidgets('보상 배너: 보상 글만 일과 언어', (tester) async {
      await pumpChild(tester, Scaffold(body: RewardBanner.maybe(jaRoutine)));

      final rich = tester.widget<Text>(find.byType(Text).first);
      final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      final prefix = spans.first;
      final reward = spans.last;
      expect(reward.text, contains('ゼリーを食べる'));
      expect(reward.style?.locale, ja);
      expect(prefix.style?.locale, isNot(ja), reason: '다하면 은 화면 문구');
    });

    // 카드 제목 어절 보호(U+2060)는 카드 글 언어가 정한다 — 화면 언어가 아니다
    for (final c in [
      (
        name: '화면 ko · 일과 ja: 일본어 제목은 끊김 방지를 넣지 않는다',
        screen: const Locale('ko'),
        language: 'ja',
        title: '服を着ます',
        joined: false,
      ),
      (
        name: '화면 en · 일과 ko: 한국어 제목은 어절을 지킨다',
        screen: const Locale('en'),
        language: 'ko',
        title: '옷을 입어요',
        joined: true,
      ),
    ]) {
      testWidgets('카드 제목 어절 보호 — ${c.name}', (tester) async {
        await pumpChild(
          tester,
          ChildRoutineDetailScreen(
            routine: Routine(
              id: 'r2',
              title: 'x',
              status: 'CONFIRMED',
              steps: [
                ActionCard(
                  id: 'k1',
                  title: c.title,
                  description: '',
                  stepOrder: 1,
                ),
              ],
              language: c.language,
            ),
          ),
          locale: c.screen,
        );

        final art = find.byWidgetPredicate(
          (w) => w is Text && w.semanticsLabel == c.title,
        );
        expect(art, findsOneWidget);
        final data = tester.widget<Text>(art).data!;
        expect(data.contains('⁠'), c.joined);
        expect(data.replaceAll('⁠', ''), c.title);
      });
    }
  });

  group('보호자 일과 목록', () {
    testWidgets('일과 타일의 제목·보상은 일과 언어, 보상 라벨은 화면 언어', (tester) async {
      await pumpWithLocale(
        tester,
        Scaffold(body: RoutineSummaryTile(routine: jaRoutine, progress: 0)),
        locale: const Locale('en'),
        wrap: (app) => ProviderScope(
          overrides: [testStorageOverride(onboardingCompleted: true)],
          child: app,
        ),
      );

      for (final t in ['学校へ行く', 'ゼリーを食べる']) {
        expect(styleLocale(tester, find.text(t)), ja, reason: t);
      }
      final label = find.text(
        tester.element(find.text('学校へ行く')).l10n.routineTileRewardLabel,
      );
      expect(label, findsOneWidget);
      expect(styleLocale(tester, label), isNot(ja));
    });

    testWidgets('임시저장 목록의 일과 제목은 일과 언어', (tester) async {
      final draft = jaRoutine.copyWith(status: 'PENDING_REVIEW');
      await pumpWithLocale(
        tester,
        const DraftRoutinesScreen(),
        locale: const Locale('en'),
        wrap: (app) => ProviderScope(
          overrides: [
            testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
            myRoutinesProvider.overrideWith((ref) async => [draft]),
          ],
          child: app,
        ),
      );
      await tester.pumpAndSettle();

      final title = find.text('学校へ行く');
      expect(title, findsOneWidget);
      expect(styleLocale(tester, title), ja);
      expect(Localizations.localeOf(tester.element(title)), const Locale('en'));
    });
  });
}

Future<void> _pumpReview(
  WidgetTester tester,
  Routine base,
  List<String> spoken,
  List<String> languages,
) async {
  final container = ProviderContainer(
    overrides: [
      offlineDioOverride(),
      testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
      speechServiceProvider.overrideWithValue(_Speech(spoken, languages)),
      routineRepositoryProvider.overrideWithValue(_Repo()),
    ],
  );
  addTearDown(container.dispose);
  container.read(routineFlowProvider.notifier).state = RoutineFlowState(
    routine: base.copyWith(status: 'PENDING_REVIEW'),
  );
  // 화면 언어는 ko(눌러야 할 한국어 라벨이 있다), 일과 언어는 ja
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          locale: const Locale('ko'),
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: AppL10n.delegates,
          routerConfig: GoRouter(
            initialLocation: Routes.routineReview,
            routes: [
              GoRoute(
                path: Routes.routineReview,
                builder: (context, state) => const CardReviewScreen(),
              ),
              GoRoute(
                path: Routes.guardian,
                builder: (context, state) => const Scaffold(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

class _Speech implements SpeechService {
  _Speech(this.spoken, this.languages);

  final List<String> spoken;
  final List<String> languages;

  @override
  Future<bool> speak(String text, {String language = 'ko'}) async {
    spoken.add(text);
    languages.add(language);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class _Repo with FakeRewardApi implements RoutineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
