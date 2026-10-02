import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/l10n/content_locale.dart';
import 'package:elum/core/l10n/l10n_context.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/data/speech_service.dart';
import 'package:elum/features/child/presentation/child_routine_detail_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/action_card_view.dart';
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

/// 두 휴대폰의 언어가 다를 때: 버튼·메뉴는 **그 휴대폰의 화면 언어**, 카드 글과 음성은
/// **일과 언어**다.
void main() {
  useFigmaViewport();

  const card = ActionCard(
    id: 'c1',
    title: '服を着ます',
    description: '学校に行く服を着ます',
    stepOrder: 1,
  );

  final spoken = <String>[];
  final languages = <String>[];

  Widget wrap({required String routineLanguage}) => ProviderScope(
    overrides: [
      offlineDioOverride(),
      testStorageOverride(onboardingCompleted: true),
      speechServiceProvider.overrideWithValue(_RecordingSpeech(spoken, languages)),
    ],
    child: ScreenUtilInit(
      designSize: const Size(393, 852),
      useInheritedMediaQuery: true,
      builder: (context, _) => MaterialApp.router(
        theme: AppTheme.light,
        // 이 휴대폰의 화면 언어는 영어다
        locale: const Locale('en'),
        supportedLocales: AppL10n.supportedLocales,
        localizationsDelegates: AppL10n.delegates,
        routerConfig: GoRouter(
          initialLocation: Routes.childRoutineDetail,
          routes: [
            GoRoute(
              path: Routes.childRoutineDetail,
              builder: (context, state) => ChildRoutineDetailScreen(
                routine: Routine(
                  id: 'local',
                  title: 'x',
                  status: 'CONFIRMED',
                  steps: const [card],
                  language: routineLanguage,
                ),
              ),
            ),
            GoRoute(
              path: Routes.childReward,
              builder: (context, state) => const Scaffold(body: Text('보상')),
            ),
          ],
        ),
      ),
    ),
  );

  setUp(() {
    spoken.clear();
    languages.clear();
  });

  testWidgets('화면 언어는 en, 카드 글은 일과 언어 ja 로 그려진다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 화면 언어는 이 휴대폰의 것이다
    final screen = tester.element(find.byType(ChildRoutineDetailScreen));
    expect(screen.l10n.localeName, 'en');

    // 카드 글은 일과 언어다 — 한자 글리프·줄바꿈이 일과 언어를 따른다
    final style = DefaultTextStyle.of(
      tester.element(find.text('学校に行く服を着ます')),
    ).style;
    expect(style.locale, contentLocaleOf('ja'));
  });

  testWidgets('카드 글 영역 안에서도 화면 문구(l10n)는 이 휴대폰 언어를 지킨다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 글자 스타일은 일과 언어(ja)이지만, 번역이 읽는 Localizations 는 화면 언어(en)로 남아야 한다
    final inCard = tester.element(find.text('学校に行く服を着ます'));
    expect(DefaultTextStyle.of(inCard).style.locale, const Locale('ja'));
    expect(Localizations.localeOf(inCard), const Locale('en'));
    expect(inCard.l10n.localeName, 'en');
  });

  /// 카드의 스피커 버튼이 누르는 동작을 그대로 부른다. 낭독 문구(번역 대상)에 기대지 않는다.
  Future<void> tapSpeaker(WidgetTester tester) async {
    final view = tester.widget<ActionCardView>(find.byType(ActionCardView).first);
    view.onSpeak!();
    await tester.pump();
  }

  testWidgets('카드를 읽어 줄 때 일과 언어를 음성에 넘긴다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tapSpeaker(tester);

    expect(spoken, ['服を着ます. 学校に行く服を着ます']);
    expect(languages, ['ja'], reason: '화면 언어(en)가 아니라 일과 언어다');
  });

  testWidgets('일과에 언어가 없으면(옛 일과) ko 로 읽는다', (tester) async {
    await tester.pumpWidget(wrap(routineLanguage: 'ko'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tapSpeaker(tester);

    expect(languages, ['ko']);
  });
}

class _RecordingSpeech implements SpeechService {
  _RecordingSpeech(this.spoken, this.languages);

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
