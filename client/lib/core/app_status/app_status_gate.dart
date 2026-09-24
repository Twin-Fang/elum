import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';
import '../theme/theme_context_ext.dart';
import '../widgets/show_failure.dart';
import 'app_status_recheck.dart';
import 'app_status_repository.dart';
import 'store_launcher.dart';

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
  /// 스토어를 못 열었을 때 붙는 식별자.
  static const storeFailureCode = 'E-UPDATE-STORE';

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

  /// 스토어를 연다. 못 열면 에러 코드와 함께 알리고 이 화면에 남는다 —
  /// 사용자는 다시 누르거나 스토어를 직접 찾아갈 수 있다.
  Future<void> _openStore(BuildContext noticeContext, Uri url) async {
    Object? error;
    var opened = false;
    try {
      opened = await ref.read(storeLauncherProvider)(url);
    } catch (e, st) {
      error = e;
      AppLogger.error('app-status', e, st, {'step': 'openStore'});
    }
    if (opened || !noticeContext.mounted) return;
    await showFailure(
      noticeContext,
      error,
      title: '스토어를 열지 못했어요',
      fallback: '스토어에서 이룸을 찾아 업데이트해주세요',
      fallbackCode: storeFailureCode,
    );
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
            onAction: (_) => ref.invalidate(appStatusProvider),
          );
        }
        if (status.requiresUpdate(result.version)) {
          // 서버가 준 주소 → 앱에 넣어 둔 주소 순서다 (#416).
          // 둘 다 없으면 예전처럼 다시 확인 버튼을 둔다.
          final storeUrl = AppConfig.storeUrl(
            defaultTargetPlatform,
            serverUrl: status.storeUrl,
          );
          return _FullNotice(
            emoji: '✨',
            title: '새 이룸이 나왔어요',
            body:
                '앱을 새로 받아야 이어서 쓸 수 있어요.\n'
                '스토어에서 이룸을 업데이트해주세요',
            // 누를 것은 하나만 둔다. 스토어에서 돌아오면 앱이 앞으로 올라오며
            // 알아서 다시 묻기 때문에 `업데이트했어요` 가 따로 필요 없다.
            actionLabel: storeUrl == null ? '업데이트했어요' : '업데이트하러 가기',
            onAction: storeUrl == null
                ? (_) => ref.invalidate(appStatusProvider)
                : (noticeContext) => _openStore(noticeContext, storeUrl),
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

  /// 안내 화면 안쪽 context 를 받는다 — 팝업을 이 화면의 Navigator 위에 띄워야 한다.
  final void Function(BuildContext context) onAction;

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
                  // 이 MaterialApp 안쪽 context 가 있어야 실패 팝업을 띄울 수 있다
                  child: Builder(
                    builder: (innerContext) => FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                      onPressed: () => onAction(innerContext),
                      child: Text(
                        actionLabel,
                        style: typo.button.copyWith(color: colors.surface),
                      ),
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
