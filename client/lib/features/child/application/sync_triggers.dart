import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'child_routine_notifier.dart';

/// 카드 진행 동기화를 언제 다시 시도할지 정하는 위젯 (이슈 #140).
///
/// 화면 트리 최상단에 한 번만 둔다. 세 시점에 [ChildRoutineNotifier.syncPending]을 부른다.
/// 1. 앱 시작 — 저장된 기록을 복원([ChildRoutineNotifier.hydrate])하고 곧바로 전송
/// 2. 백그라운드에서 돌아올 때
/// 3. 네트워크가 오프라인 → 온라인으로 바뀔 때 (짧은 debounce로 이벤트 폭주 방어)
///
/// 카드 조작 직후 전송은 notifier 안에서 하므로 여기서 다루지 않는다.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _debounce;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 첫 프레임 뒤에 복원한다 — build 중 provider 상태를 바꾸면 안 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(childRoutineProvider.notifier).hydrate());
    });

    // 위젯 테스트에는 플랫폼 채널이 없어 스트림이 열리지 않는다 — 실패해도 앱은 뜬다.
    try {
      _connectivity = Connectivity().onConnectivityChanged.listen(
        _onConnectivity,
      );
    } catch (_) {
      _connectivity = null;
    }
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      _wasOffline = true;
      return;
    }
    // 온라인이 됐을 때만, 그것도 오프라인을 거친 뒤에만 보낸다.
    // 시작 직후 온라인 이벤트는 hydrate가 이미 처리한다.
    if (!_wasOffline) return;
    _wasOffline = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) ref.read(childRoutineProvider.notifier).syncPending();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(childRoutineProvider.notifier).syncPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
