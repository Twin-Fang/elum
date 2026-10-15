import 'dart:io';

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 서버 요청 중 뒤로가기 잠금: 제목줄은 남기고 누름만 막는다.
///
/// 깨지면: 요청 중에 제목줄이 사라져 본문이 위로 튀었다가 내려온다.
void main() {
  const bodyKey = Key('body');

  Widget wrap({required bool isBackEnabled, required VoidCallback onBack}) =>
      ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: ElumScaffold(
            title: '제목',
            onBack: onBack,
            isBackEnabled: isBackEnabled,
            child: const SizedBox(key: bodyKey, height: 10),
          ),
        ),
      );

  testWidgets('뒤로가기를 막아도 제목줄과 본문 위치는 그대로고 누름만 무시한다', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      wrap(isBackEnabled: true, onBack: () => backCount++),
    );
    final enabledBodyTop = tester.getTopLeft(find.byKey(bodyKey)).dy;

    await tester.pumpWidget(
      wrap(isBackEnabled: false, onBack: () => backCount++),
    );
    expect(find.text('제목'), findsOneWidget);
    expect(find.bySemanticsLabel('뒤로 가기'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(bodyKey)).dy, enabledBodyTop);

    await tester.tap(find.bySemanticsLabel('뒤로 가기'));
    expect(backCount, 0);
  });

  // onBack 을 진행 상태로 비우면 제목줄이 빠진다 — isBackEnabled 로만 막는다.
  test('화면 코드가 진행 상태로 onBack 을 비우지 않는다', () {
    final nullOnBusy = RegExp(r'onBack:\s*!?[\w.]+\s*\?\s*null\s*:');
    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (nullOnBusy.hasMatch(entity.readAsStringSync())) {
        violations.add(entity.path);
      }
    }
    expect(violations, isEmpty);
  });
}
