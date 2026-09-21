import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_status_repository.dart';

/// 앱이 시작할 때 서버 상태를 확인하고, 필요하면 화면을 대신 그린다 (이슈 #279).
///
/// **확인하지 못하면 그냥 통과시킨다.** 서버를 못 봤다는 이유로 앱을 세우면
/// 정작 서버가 죽었을 때 아무도 앱을 열지 못한다. 기다리는 동안도 마찬가지다 —
/// 로딩 화면을 끼워 넣으면 매번 시작이 느려진다.
class AppStatusGate extends ConsumerWidget {
  const AppStatusGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appStatusProvider);

    return async.maybeWhen(
      data: (result) {
        final status = result.status;
        if (status.maintenance) {
          return _FullNotice(
            emoji: '🛠️',
            title: '잠시 쉬고 있어요',
            body: status.maintenanceMessage.isEmpty
                ? '조금 뒤에 다시 열어주세요'
                : status.maintenanceMessage,
            actionLabel: '다시 확인하기',
            onAction: () => ref.invalidate(appStatusProvider),
          );
        }
        if (status.requiresUpdate(result.version)) {
          return _FullNotice(
            emoji: '✨',
            title: '새 이룸이 나왔어요',
            // 스토어로 보내는 버튼은 아직 없다. iOS 앱 ID가 정해지면 넣는다 (#279).
            body: '앱을 새로 받아야 이어서 쓸 수 있어요.\n'
                '스토어에서 이룸을 업데이트해주세요',
            actionLabel: '업데이트했어요',
            onAction: () => ref.invalidate(appStatusProvider),
          );
        }
        return child;
      },
      // 기다리는 중·실패 — 어느 쪽이든 앱을 막지 않는다
      orElse: () => child,
    );
  }
}

/// 화면 전체를 대신하는 안내.
///
/// 이룸이도 보는 화면이라 저장소 규칙을 따른다 — 빨강·경고 아이콘을 쓰지 않고,
/// 누를 것은 하나만 두며, 터치 영역을 64 이상으로 잡는다.
class _FullNotice extends StatelessWidget {
  const _FullNotice({
    required this.emoji,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final String emoji;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      home: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: 64.sp)),
                SizedBox(height: 24.h),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: typo.promptTitle.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: 12.h),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: typo.promptBody.copyWith(color: colors.textSecondary),
                ),
                SizedBox(height: 40.h),
                SizedBox(
                  width: double.infinity,
                  height: 66.h, // 이룸이 화면 최소 터치 규칙
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                    ),
                    onPressed: onAction,
                    child: Text(
                      actionLabel,
                      style: typo.button.copyWith(color: colors.surface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
