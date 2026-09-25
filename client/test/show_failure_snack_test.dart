import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/show_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 실패 스낵바는 하단 버튼을 가리지 않는다 (이슈 #427 ④).
///
/// 카드 확인에서 새 일과를 처음 저장할 때 인터넷이 끊기면, 기본 스낵바가 화면 바닥에
/// 붙어 `저장하기` 버튼 대부분을 덮었다 (실기기 실측). 다시 누르려면 스낵바가 사라질
/// 때까지 기다려야 했다.
void main() {
  useFigmaViewport();

  const buttonKey = ValueKey('bottom-cta');

  Future<void> pumpWithCta(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Stack(
                children: [
                  Center(
                    child: TextButton(
                      onPressed: () => showFailureSnack(
                        context,
                        const AppFailure(fault: NetworkFault.offline),
                        fallback: '일과를 저장하지 못했어요. 다시 해주세요',
                        fallbackCode: 'E-SAVE',
                      ),
                      child: const Text('실패'),
                    ),
                  ),
                  // 카드 확인의 `저장하기` 자리 — 좌우 16, 아래 24, 높이 66.
                  const Positioned(
                    key: buttonKey,
                    left: 16,
                    right: 16,
                    bottom: 24,
                    height: 66,
                    child: ColoredBox(color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('실패'));
    await tester.pumpAndSettle();
  }

  testWidgets('스낵바가 하단 버튼 위에 뜬다', (tester) async {
    await pumpWithCta(tester);

    // SnackBar 위젯 영역에는 바깥 여백까지 들어간다 — 보이는 면(Material)을 잰다.
    final snack = tester.getRect(find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first);
    final cta = tester.getRect(find.byKey(buttonKey));
    expect(snack.bottom, lessThanOrEqualTo(cta.top),
        reason: '버튼을 덮으면 다시 누를 수 없다');
  });

  testWidgets('할 일은 한 번만 말한다', (tester) async {
    await pumpWithCta(tester);

    expect(
      find.text('일과를 저장하지 못했어요 · 인터넷 연결을 확인해주세요 (E-NET-OFFLINE)'),
      findsOneWidget,
    );
  });
}
