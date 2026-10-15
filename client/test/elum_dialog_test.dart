import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 공통 팝업 (Figma `팝업` 732:5835 · 이슈 #232).
///
/// **이 위젯은 한 화면 전용이 아니다.** 연결 성공으로 처음 쓰지만 확인·경고·삭제
/// 확인이 뒤따른다. 그래서 "빠뜨렸을 때 무엇이 사라지는가"를 테스트로 고정한다 —
/// 아이콘 없이, 버튼 없이, 버튼 둘로도 서야 한다.
void main() {
  useFigmaViewport();

  /// 팝업을 띄우고 눌린 버튼의 값을 돌려받는다.
  Future<T?> open<T>(
    WidgetTester tester, {
    required String title,
    String? message,
    ElumDialogIcon? icon,
    List<ElumDialogAction<T>> actions = const [],
    bool barrierDismissible = false,
  }) async {
    T? result;
    late BuildContext ctx;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    showElumDialog<T>(
      context: ctx,
      title: title,
      message: message,
      icon: icon,
      actions: actions,
      barrierDismissible: barrierDismissible,
    ).then((v) => result = v);
    await tester.pumpAndSettle();

    return result;
  }

  // #393 S7 — 앱에 한국어 지역화가 없어 배경 막이 영어 `Dismiss` 로 읽혔다.
  // 공지 팝업만 `공지 닫기`로 고쳐 두었다(#385 C). 공통 팝업도 한국어로 읽는다.
  testWidgets('바깥을 눌러 닫는 팝업의 배경 막은 팝업 닫기로 읽힌다 (#393 S7)', (tester) async {
    final handle = tester.ensureSemantics();
    await open<void>(tester, title: '보상이 왜 필요한가요?', barrierDismissible: true);

    expect(find.bySemanticsLabel('Dismiss'), findsNothing);
    expect(find.bySemanticsLabel('팝업 닫기'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('바깥을 눌러도 안 닫히는 팝업은 배경 막을 읽지 않는다 (#393 S7)', (tester) async {
    final handle = tester.ensureSemantics();
    await open<void>(tester, title: '로그아웃할까요?');

    // 눌러도 아무 일이 없는 자리를 `닫기`로 읽으면 낭독기 사용자가 헛누른다.
    expect(find.bySemanticsLabel('Dismiss'), findsNothing);
    expect(find.bySemanticsLabel('팝업 닫기'), findsNothing);
    handle.dispose();
  });






  testWidgets('누른 버튼의 값이 돌아온다', (tester) async {
    String? picked;
    late BuildContext ctx;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    showElumDialog<String>(
      context: ctx,
      title: '정말 지울까요?',
      actions: const [
        ElumDialogAction(label: '취소', value: 'cancel'),
        ElumDialogAction(label: '지우기', value: 'delete'),
      ],
    ).then((v) => picked = v);
    await tester.pumpAndSettle();

    await tester.tap(find.text('지우기'));
    await tester.pumpAndSettle();

    // 무엇을 눌렀는지 구분되지 않으면 확인·취소를 나눌 수 없다.
    expect(picked, 'delete');
  });
}
