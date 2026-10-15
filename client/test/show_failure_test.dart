import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/show_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 실패는 시안 `로그인실패`(1045:5079) 팝업 하나로 말한다 (#433).
///
/// 예전에는 노란 경고 팝업과 스낵바로 나눠 보였다. 시안에는 둘 다 없다.
void main() {
  useFigmaViewport();

  Future<void> fail(WidgetTester tester, Object? error,
      {String? title, String fallback = '잠시 후 다시 시도해주세요'}) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showFailure(
                  context,
                  error,
                  title: title,
                  fallback: fallback,
                  fallbackCode: 'E-TEST',
                ),
                child: const Text('실패'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('실패'));
    await tester.pumpAndSettle();
  }

  ElumDialogCard<void> card(WidgetTester tester) =>
      tester.widget(find.byType(ElumDialogCard<void>));

  testWidgets('식별자는 문장 밖, 팝업 안에 글자로 보인다', (tester) async {
    await fail(tester, null, title: '로그인하지 못했어요');

    expect(find.text('E-TEST'), findsOneWidget);
    // 문장에 섞이면 두 줄이 세 줄로 꺾인다
    expect(card(tester).title, isNot(contains('E-TEST')));
  });

  testWidgets('인터넷이 끊겼으면 할 일 자리를 인터넷 안내로 바꾼다', (tester) async {
    await fail(
      tester,
      const AppFailure(fault: NetworkFault.offline),
      title: '일과를 저장하지 못했어요',
    );

    expect(card(tester).title, '일과를 저장하지 못했어요.\n인터넷 연결을 확인해주세요');
    expect(find.text(NetworkFault.offline.wire), findsOneWidget);
  });

  testWidgets('앱이 스스로 끊은 요청이면 아무것도 띄우지 않는다', (tester) async {
    await fail(tester, const AppFailure(fault: NetworkFault.cancelled),
        title: '로그인하지 못했어요');

    expect(find.byType(ElumDialogCard<void>), findsNothing);
  });

  group('failureSentence', () {
  });
}
