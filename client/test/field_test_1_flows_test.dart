import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/routine_template_sheet.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_reminder_row.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_reminder_sheet.dart';
import 'package:elum/features/reminder/application/routine_reminder_controller.dart';
import 'package:elum/features/reminder/data/reminder_scheduler.dart';
import 'package:elum/features/reminder/domain/routine_reminder.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

class _FakeScheduler implements ReminderScheduler {
  final scheduled = <RoutineReminder>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(RoutineReminder reminder, ReminderTexts texts) async =>
      scheduled.add(reminder);

  @override
  Future<void> cancel(RoutineReminder reminder) async {}
}

Widget _app(Widget home, {List<Object> overrides = const []}) => ProviderScope(
  overrides: [
    testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
    routineSuggestionsProvider.overrideWith(
      (ref) async => RoutineSuggestion.fallback,
    ),
    ...overrides.cast(),
  ],
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ko'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // 배경 오로라가 무한 반복이라 멈춘다 (기존 골든 시험과 같다)
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: home,
    ),
  ),
);

void main() {
  useFigmaViewport();

  // 깨지면: 예시 일과를 골라도 입력칸이 비어 보호자가 처음부터 써야 한다
  testWidgets('예시 일과 > 카테고리 > 고르면 입력칸에 문장이 채워진다', (tester) async {
    await tester.pumpWidget(_app(const RoutineInputScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('예시 일과 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineTemplateSheet), findsOneWidget);

    // 카테고리 줄은 가로로 넘긴다 — 화면 밖 칩까지 끌어와 누른다
    await tester.ensureVisible(find.text('공부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('공부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('숙제 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(RoutineTemplateSheet), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, contains('숙제를 스스로 시작해서'));
  });

  // 깨지면: 보호자가 알림을 켜도 시트에 반영되지 않아 켜졌는지 알 수 없다
  testWidgets('알림 줄 > 시트 > 알림 켜기 > 줄에 매일 시각이 보인다', (tester) async {
    final scheduler = _FakeScheduler();
    const routine = Routine(id: 'r1', title: '양치하기', status: 'CONFIRMED');
    await tester.pumpWidget(
      _app(
        const Scaffold(body: RoutineReminderRow(routine: routine)),
        overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('알림 없음'), findsOneWidget);

    await tester.tap(find.byKey(RoutineReminderRow.rowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(RoutineReminderSheet.saveButtonKey));
    await tester.pumpAndSettle();

    expect(scheduler.scheduled.single.routineTitle, '양치하기');
    expect(scheduler.scheduled.single.isDaily, isTrue);
    expect(find.textContaining('매일'), findsOneWidget);
    expect(find.textContaining('8:00'), findsOneWidget);
  });
}
