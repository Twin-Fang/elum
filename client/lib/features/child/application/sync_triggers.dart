import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guardian/data/routine_repository.dart';
import 'child_routine_notifier.dart';

/// 카드 진행 동기화를 언제 다시 시도할지 정하는 위젯 (이슈 #140).
///
/// 화면 트리 최상단에 한 번만 둔다. 세 시점에 [ChildRoutineNotifier.syncPending]을 부른다.
/// 1. 앱 시작 — 저장된 기록을 복원([ChildRoutineNotifier.hydrate])하고 곧바로 전송
/// 2. 백그라운드에서 돌아올 때
/// 3. 네트워크가 오프라인 → 온라인으로 바뀔 때 (짧은 debounce로 이벤트 폭주 방어)
///
/// 카드 조작 직후 전송은 notifier 안에서 하므로 여기서 다루지 않는다.
///
/// 날짜가 바뀌면 일과 목록도 다시 받는다 (#353). 목록 provider 는 앱이 살아 있는 동안
/// 값을 들고 있어서, 자정을 넘기고도 다시 받지 않으면 어제 일과가 오늘 일과로 남는다.
/// 백그라운드에서 돌아올 때와 켜 둔 채 자정이 지날 때 둘 다 본다.
class SyncTriggers extends ConsumerStatefulWidget {
  const SyncTriggers({super.key, required this.child, this.now});

  final Widget child;

  /// 현재 시각. 테스트가 자정 넘김을 흉내내려고 바꾼다. 기본은 기기 시계.
  final DateTime Function()? now;

  @override
  ConsumerState<SyncTriggers> createState() => _SyncTriggersState();
}

class _SyncTriggersState extends ConsumerState<SyncTriggers>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  Timer? _debounce;
  bool _wasOffline = false;

  /// 일과 목록을 마지막으로 맞춘 날짜(시각 없는 날짜).
  late DateTime _listDay;
  Timer? _midnight;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listDay = _dayOf(_now());
    _scheduleMidnight();

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

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  /// 다음 자정 직후에 날짜를 확인한다. 앱을 내리지 않고 켜 둔 채 날이 바뀌는 경우다.
  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = _now();
    // 정각에 딱 맞추면 시계 오차로 아직 어제일 수 있어 몇 초 여유를 둔다.
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      if (!mounted) return;
      _refreshIfDayChanged();
      _scheduleMidnight();
    });
  }

  /// 날짜가 바뀌었으면 일과 목록 셋을 다시 받는다 — 어제 일과를 오늘에서 치운다.
  void _refreshIfDayChanged() {
    final today = _dayOf(_now());
    if (today == _listDay) return;
    _listDay = today;
    ref.refreshRoutines();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfDayChanged();
      ref.read(childRoutineProvider.notifier).syncPending();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivity?.cancel();
    _debounce?.cancel();
    _midnight?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
