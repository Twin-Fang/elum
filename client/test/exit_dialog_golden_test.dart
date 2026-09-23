@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 공통 팝업의 세 무게 (이슈 #242).
///
/// **`warn`을 새로 더했다.** `danger`(되돌릴 수 없는 파괴)와 `primary`(주 동작)
/// 사이가 비어 있어, 나가기처럼 "지금 잃는다"를 말할 자리가 없었다.
void main() {
  useFigmaViewport();

  Widget wrap(Widget child) => ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            backgroundColor: AppTheme.light.scaffoldBackgroundColor,
            body: Center(child: child),
          ),
        ),
      );

  // 나가기 팝업의 말은 시점마다 다르다 (#387). 문구는 `RoutineLeave.copyOf` 한 곳에서 온다.
  Widget leaveCard(RoutineLeave kind) {
    final (title, message) = RoutineLeave.copyOf(kind);
    final loses = kind == RoutineLeave.discard;
    return ElumDialogCard<bool>(
      icon: loses ? ElumDialogIcon.warning : null,
      title: title,
      message: message,
      actions: [
        const ElumDialogAction(
          label: '계속 만들기',
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: '나가기',
          value: true,
          tone: loses ? ElumDialogTone.warn : ElumDialogTone.primary,
        ),
      ],
    );
  }

  testWidgets('나갈 때 팝업 — 카드 만들기 전 (warn)', (tester) async {
    await tester.pumpWidget(wrap(leaveCard(RoutineLeave.discard)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumDialogCard<bool>),
      matchesGoldenFile('goldens/dialog_warn_exit.png'),
    );
  });

  testWidgets('나갈 때 팝업 — 카드 만든 뒤 (임시저장 · 경고 아님)', (tester) async {
    await tester.pumpWidget(wrap(leaveCard(RoutineLeave.draft)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumDialogCard<bool>),
      matchesGoldenFile('goldens/dialog_draft_exit.png'),
    );
  });

  testWidgets('나갈 때 팝업 — 카드 만드는 중 (다 만들어지면 임시저장)', (tester) async {
    await tester.pumpWidget(wrap(leaveCard(RoutineLeave.draftWhenReady)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumDialogCard<bool>),
      matchesGoldenFile('goldens/dialog_draft_ready_exit.png'),
    );
  });

  testWidgets('나갈 때 팝업 — 저장한 일과를 고치다', (tester) async {
    await tester.pumpWidget(wrap(leaveCard(RoutineLeave.edit)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumDialogCard<bool>),
      matchesGoldenFile('goldens/dialog_edit_exit.png'),
    );
  });

  testWidgets('세 무게를 나란히 — primary · warn · danger', (tester) async {
    await tester.pumpWidget(wrap(
      const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElumDialogCard<void>(
              icon: ElumDialogIcon.success,
              title: '휴대폰 연결에 성공했어요!',
            ),
            SizedBox(height: 16),
            ElumDialogCard<bool>(
              icon: ElumDialogIcon.warning,
              title: '만들던 일과가 사라져요',
              actions: [
                ElumDialogAction(
                  label: '계속 만들기',
                  tone: ElumDialogTone.neutral,
                ),
                ElumDialogAction(label: '나가기', tone: ElumDialogTone.warn),
              ],
            ),
            SizedBox(height: 16),
            ElumDialogCard<bool>(
              title: '정말 탈퇴할까요?',
              actions: [
                ElumDialogAction(label: '취소', tone: ElumDialogTone.neutral),
                ElumDialogAction(label: '탈퇴', tone: ElumDialogTone.danger),
              ],
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SingleChildScrollView),
      matchesGoldenFile('goldens/dialog_tones.png'),
    );
  });
}
