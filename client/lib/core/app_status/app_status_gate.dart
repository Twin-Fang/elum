import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_status_recheck.dart';
import 'app_status_repository.dart';

/// 앱이 시작할 때 서버 상태를 확인하고, 필요하면 화면을 대신 그린다 (이슈 #279).
///
/// **확인하지 못하면 그냥 통과시킨다.** 서버를 못 봤다는 이유로 앱을 세우면
/// 정작 서버가 죽었을 때 아무도 앱을 열지 못한다. 기다리는 동안도 마찬가지다 —
/// 로딩 화면을 끼워 넣으면 매번 시작이 느려진다.
///
/// **앱이 다시 앞으로 올라오면 다시 묻는다.** 전에는 시작할 때 한 번뿐이라, 점검을
/// 켜기 전에 앱을 연 사람은 다시 켤 때까지 점검 사실을 몰랐다 (#279 QA).
class AppStatusGate extends ConsumerStatefulWidget {
  const AppStatusGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppStatusGate> createState() => _AppStatusGateState();
}

class _AppStatusGateState extends ConsumerState<AppStatusGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appStatusRecheckProvider.notifier).request();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appStatusProvider);

    return async.maybeWhen(
      // 다시 묻는 동안에는 **직전 화면을 그대로 둔다.** 그러지 않으면 점검 화면에서
      // 앱 화면이 잠깐 튀어나와 요청을 보내고, 그 요청이 또 503을 받아 되묻기를 반복한다.
      skipLoadingOnReload: true,
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
        return widget.child;
      },
      // 처음 기다리는 중·실패 — 어느 쪽이든 앱을 막지 않는다
      orElse: () => widget.child,
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
