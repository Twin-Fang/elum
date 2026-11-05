import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../layout/adaptive_page_frame.dart';
import '../layout/screen_layout_kind.dart';
import '../logger/app_logger.dart';
import '../config/app_config.dart';
import '../dev/app_restart.dart';
import '../dev/dev_simulation.dart';
import '../dev/dev_skip_notice_button.dart';
import 'app_status_recheck.dart';
import 'app_status_repository.dart';
import 'update_suggestion.dart';
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
  // 새 서버로 다시 띄우기 요청은 한 번만 (같은 결과로 여러 번 불려도)
  bool _hasRequestedServerRestart = false;

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

  /// 새 서버 주소 확인 완료 > 다음 프레임에 앱을 안에서 다시 띄움 (로그아웃·캐시 비우기 없음, #831)
  void _restartOnNewServer() {
    if (_hasRequestedServerRestart) return;
    _hasRequestedServerRestart = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isRestarted = AppRestart.restart(context);
      AppLogger.info(
        '[server address] restart : ${isRestarted ? 'now' : 'no restart host, next launch'} -> ${AppConfig.apiBaseUrl}',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 막는 화면 흉내를 건너뛰는 중에도 새 서버 전환은 함
    ref.listen(appStatusProvider, (previous, next) {
      if (next.value?.isServerSwitchReady ?? false) _restartOnNewServer();
    });
    // 테스트 빌드에서 `그냥 계속하기`를 누르면 막는 화면 대신 앱을 그림
    return ValueListenableBuilder<bool>(
      valueListenable: DevSimulation.isBlockingNoticeSkipped,
      builder: (context, _, _) => DevSimulation.shouldSkipBlockingNotice
          ? widget.child
          : _buildGate(context),
    );
  }

  Widget _buildGate(BuildContext context) {
    final async = ref.watch(appStatusProvider);
    // 개발자 도구 빌드만 막는 화면 아래 `그냥 계속하기`
    final skipButton =
        DevSimulation.canSkipBlockingNotice ? const DevSkipNoticeButton() : null;

    return async.maybeWhen(
      // 다시 묻는 동안에는 **직전 화면을 그대로 둔다.** 그러지 않으면 점검 화면에서
      // 앱 화면이 잠깐 튀어나와 요청을 보내고, 그 요청이 또 503을 받아 되묻기를 반복한다.
      skipLoadingOnReload: true,
      data: (result) {
        // 새 서버로 다시 띄우기 직전 > 옛 서버의 점검·업데이트 화면을 그리지 않음
        if (result.isServerSwitchReady) return widget.child;
        final status = result.status;
        if (status.isUnderMaintenance) {
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
                footer: skipButton,
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
                    : (noticeContext) =>
                          startUpdateOrOpenStore(noticeContext, ref, storeUrl),
                footer: skipButton,
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
