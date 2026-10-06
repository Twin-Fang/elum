import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 토스트는 한 함수로 띄운다 — 쌓이지 않고, 띄울 자리가 없어도 앱이 멈추지 않는다.
void main() {
  Widget app() => MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: Center(child: Text('본문'))),
  );

  testWidgets('연달아 띄우면 앞 것을 지우고 마지막 것만 보인다', (tester) async {
    await tester.pumpWidget(app());
    final context = tester.element(find.text('본문'));

    showElumToast(context, '첫째');
    showElumToast(context, '둘째');
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('둘째'), findsOneWidget);
    expect(find.text('첫째'), findsNothing);

    // 앞 것이 줄 서 있지 않다 — 둘째가 닫히면 아무것도 남지 않는다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('모양은 화면이 아니라 테마가 정한다', (tester) async {
    await tester.pumpWidget(app());
    showElumToast(tester.element(find.text('본문')), '그림 방식을 바꿨어요');
    await tester.pump();

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, isNull);
    expect(bar.backgroundColor, isNull);
  });

  testWidgets('띄울 자리가 없어도 예외 없이 넘어간다', (tester) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFFFFFFFF),
        builder: (context, _) =>
            const Text('맨몸', textDirection: TextDirection.ltr),
      ),
    );
    showElumToast(tester.element(find.text('맨몸')), '알림');
    showElumToastOn(null, '알림');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
