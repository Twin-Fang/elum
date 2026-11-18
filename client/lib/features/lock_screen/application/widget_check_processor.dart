import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/lock_screen/home_widget_bridge.dart';
import '../../../core/lock_screen/lock_screen_snapshot.dart';
import '../../../core/logger/app_logger.dart';
import '../../../shared/models/action_card.dart';
import '../../../shared/models/routine.dart';

/// 위젯에서 체크한 카드 > 앱 진행 기록 (#1465 2단계)
/// 받는 때 3가지: 앱 시작 · 앞으로 돌아옴 · Android 위젯 신호 > 오늘 일과에서 찾아 체크 (기기 저장 > 서버 전송은 기존 흐름)
/// 이룸이 기기만 · 오늘이 아니거나 못 찾은 카드는 버림
class WidgetCheckProcessor with WidgetsBindingObserver {
  WidgetCheckProcessor({
    required this.bridge,
    required this.isElumiDevice,
    required this.loadTodayRoutines,
    required this.markChecked,
  });

  final HomeWidgetBridge bridge;
  final bool Function() isElumiDevice;
  final Future<List<Routine>> Function() loadTodayRoutines;

  /// 카드 체크 (이미 체크됐으면 false)
  final bool Function(Routine routine, ActionCard card) markChecked;

  StreamSubscription<void>? _signalSubscription;

  // 처리 중 겹침 막기 (시작 · 복귀 · 신호가 한꺼번에 올 때)
  Future<void> _running = Future<void>.value();

  void start() {
    if (!bridge.isSupported) return;
    WidgetsBinding.instance.addObserver(this);
    _signalSubscription = bridge.widgetChecksAdded.listen((_) => _scheduleProcess());
    _scheduleProcess();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signalSubscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleProcess();
  }

  void _scheduleProcess() {
    _running = _running.then((_) => _process()).catchError((Object error, StackTrace stack) {
      // 처리 실패해도 홈은 그대로 (로그만)
      AppLogger.error('[widget check] process failed', error, stack);
    });
  }

  // 대기열 꺼내기 > 오늘 · 찾은 카드만 체크
  Future<void> _process() async {
    if (!isElumiDevice()) return;
    final checks = await bridge.takeWidgetChecks();
    if (checks.isEmpty) return;
    final todayKey = LockScreenSnapshot.dateKeyOf(DateTime.now());
    final routines = await loadTodayRoutines();
    var appliedCount = 0;
    for (final check in checks) {
      if (check.dateKey != todayKey) {
        AppLogger.info('[widget check] dropped : not today');
        continue;
      }
      final routine = routines.where((routine) => routine.id == check.routineId).firstOrNull;
      final card = routine?.steps.where((card) => card.id == check.cardId).firstOrNull;
      if (routine == null || card == null) {
        AppLogger.info('[widget check] dropped : card not in today routines');
        continue;
      }
      if (markChecked(routine, card)) appliedCount += 1;
    }
    AppLogger.info('[widget check] applied : $appliedCount');
  }
}
