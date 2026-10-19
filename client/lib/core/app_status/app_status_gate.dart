import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../layout/adaptive_page_frame.dart';
import '../layout/screen_layout_kind.dart';
import '../config/app_config.dart';
import '../logger/app_logger.dart';
import '../widgets/show_failure.dart';
import 'app_status_recheck.dart';
import 'app_status_repository.dart';
import 'store_launcher.dart';
import 'app_notice_card.dart';

/// 앱이 시작할 때 서버 상태를 확인하고, 필요하면 화면을 대신 그린다.
///
/// **확인하지 못하면 그냥 통과시킨다.** 서버를 못 봤다는 이유로 앱을 세우면
/// 정작 서버가 죽었을 때 아무도 앱을 열지 못한다. 기다리는 동안도 마찬가지다 —
/// 로딩 화면을 끼워 넣으면 매번 시작이 느려진다.
///
/// **앱이 다시 앞으로 올라오면 다시 묻는다.** 시작할 때 한 번만 물으면, 점검을
/// 켜기 전에 앱을 연 사람은 점검 사실을 모른다.
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
    // await 뒤에서 context 를 쓰지 않도록 문구를 먼저 잡는다.
    final l10n = noticeContext.l10n;
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
      title: l10n.appStatusStoreOpenFailedTitle,
      fallback: l10n.appStatusStoreOpenFailedFallback,
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
          return AdaptivePageFrame(
            kind: ScreenLayoutKind.phoneColumn,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Theme.of(context),
              home: AppNoticeCard(
                imageAsset: AppAssets.maintenanceLumi,
                title: context.l10n.appStatusMaintenanceTitle,
                body: status.maintenanceMessage.isEmpty
                    ? context.l10n.appStatusMaintenanceBody
                    : status.maintenanceMessage,
                actionLabel: context.l10n.appStatusRecheck,
                onAction: (_) => ref.invalidate(appStatusProvider),
              ),
            ),
          );
        }
        if (status.requiresUpdate(result.version)) {
          // 서버가 준 주소 → 앱에 넣어 둔 주소 순서다.
          // 둘 다 없으면 다시 확인 버튼을 둔다.
          final storeUrl = AppConfig.storeUrl(
            defaultTargetPlatform,
            serverUrl: status.storeUrl,
          );
          return AdaptivePageFrame(
            kind: ScreenLayoutKind.phoneColumn,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: Theme.of(context),
              home: AppNoticeCard(
                imageAsset: AppAssets.updateLumi,
                title: context.l10n.appStatusUpdateTitle,
                // 누를 것은 하나만 둔다. 스토어에서 돌아오면 앱이 앞으로 올라오며
                // 알아서 다시 묻기 때문에 `업데이트했어요` 가 따로 필요 없다.
                actionLabel: storeUrl == null
                    ? context.l10n.appStatusUpdated
                    : context.l10n.appStatusGoUpdate,
                onAction: storeUrl == null
                    ? (_) => ref.invalidate(appStatusProvider)
                    : (noticeContext) => _openStore(noticeContext, storeUrl),
              ),
            ),
          );
        }
        return widget.child;
      },
      // 처음 기다리는 중·실패 — 어느 쪽이든 앱을 막지 않는다
      orElse: () => widget.child,
    );
  }
}
