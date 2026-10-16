import 'package:elum/core/l10n/current_l10n.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_detail_sheet.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/device_viewport.dart';
import '../helpers/fake_dio.dart';
import '../helpers/fake_reward_api.dart';
import '../helpers/pump_with_locale.dart';
import '../helpers/test_storage.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

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

}

class _Speech implements SpeechService {
  _Speech(this.spoken, this.languages);

  final List<String> spoken;
  final List<String> languages;

  @override
  Future<bool> speak(String text, {String language = 'ko', StoredSpeechSource? stored}) async {
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
