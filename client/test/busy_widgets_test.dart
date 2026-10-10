import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/core/widgets/elum_spinner.dart';
import 'package:elum/core/widgets/settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 진행 중 표시를 담는 공통 위젯.
///
/// 응답을 기다리는 동안 다시 눌리면 같은 요청이 두 번 간다. 위젯이 직접 막아야
/// 화면마다 빠뜨리지 않는다.
void main() {
  useFigmaViewport();

  Widget app(Widget home) => ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp(theme: AppTheme.light, home: home),
      );

  group('ElumButton(loading:)', () {
    testWidgets('진행 중이면 눌러도 부르지 않고 스피너가 돈다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(Scaffold(
        body: ElumButton(label: '저장하기', loading: true, onPressed: () => taps++),
      )));

      await tester.tap(find.text('저장하기'));
      await tester.pump();

      expect(taps, 0);
      expect(find.byType(ElumSpinner), findsOneWidget);
      expect(find.text('저장하기'), findsOneWidget, reason: '문구는 그대로 둔다');
    });

    testWidgets('기본은 스피너 없이 눌린다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(Scaffold(
        body: ElumButton(label: '저장하기', onPressed: () => taps++),
      )));

      await tester.tap(find.text('저장하기'));
      await tester.pump();

      expect(taps, 1);
      expect(find.byType(ElumSpinner), findsNothing);
    });
  });

  testWidgets('SettingsTile(loading:) 은 화살표 대신 스피너를 그리고 눌리지 않는다',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(app(Scaffold(
      body: SettingsTile(label: '로그아웃', loading: true, onTap: () => taps++),
    )));

    await tester.tap(find.text('로그아웃'));
    await tester.pump();

    expect(taps, 0);
    expect(find.byType(ElumSpinner), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });
}
