import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';

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
    ).then((v) => result = v);
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('버튼을 주지 않으면 확인 하나가 선다', (tester) async {
    await open<void>(tester, title: '휴대폰 연결에 성공했어요!');

    // 팝업을 띄울 때마다 "확인"을 적게 하지 않는다 — 가장 흔한 모양이 기본값이다.
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('아이콘을 주면 그림이 붙는다', (tester) async {
    await open<void>(
      tester,
      title: '휴대폰 연결에 성공했어요!',
      icon: ElumDialogIcon.success,
    );

    expect(svgWithAsset(AppAssets.dialogCheck), findsOneWidget);
  });

  testWidgets('아이콘을 주지 않으면 자리도 없다', (tester) async {
    await open<void>(tester, title: '아이콘 없는 팝업');

    // 빈 원이 남으면 무엇을 뜻하는지 모를 자리가 하나 생긴다.
    expect(svgWithAsset(AppAssets.dialogCheck), findsNothing);
  });

  testWidgets('설명은 선택이다', (tester) async {
    await open<void>(tester, title: '제목', message: '한 줄 더');

    expect(find.text('제목'), findsOneWidget);
    expect(find.text('한 줄 더'), findsOneWidget);
  });

  testWidgets('버튼 둘을 나란히 놓을 수 있다', (tester) async {
    await open<String>(
      tester,
      title: '정말 지울까요?',
      actions: const [
        ElumDialogAction(
          label: '취소',
          value: 'cancel',
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: '지우기',
          value: 'delete',
          tone: ElumDialogTone.danger,
        ),
      ],
    );

    expect(find.text('취소'), findsOneWidget);
    expect(find.text('지우기'), findsOneWidget);
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
