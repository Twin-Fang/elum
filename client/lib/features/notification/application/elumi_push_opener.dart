import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/current_l10n.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../guardian/application/routine_providers.dart';

final elumiPushOpenerProvider = Provider<ElumiPushOpener>(
  ElumiPushOpener.new,
);

/// 이룸이 기기 푸시 처리: 전경 수신(일과 목록 새로 받기), 누름 > 이룸이 화면 준비 대기 > 그 일과 상세
/// 보호자 알림과 따로 둠 (이룸이 기기는 알림 목록·읽음 처리가 없음)
class ElumiPushOpener {
  ElumiPushOpener(this._ref);

  final Ref _ref;

  /// 서버 PushMessageFactory.ELUMI_ROUTINE_ARRIVED_TYPE 과 같은 값
  static const routineArrivedType = 'ELUMI_ROUTINE_ARRIVED';

  /// 서버 PushMessageFactory.ELUMI_ROUTINES_CHANNEL_ID 와 같은 값
  static const routinesChannelId = 'elumi_routines';

  // 눌렀지만 이룸이 화면이 준비되지 않았을 때 기다려 주는 시간 (그 뒤엔 낡은 이동이라 버림)
  static const _pendingOpenValidity = Duration(seconds: 30);

  String? _pendingRoutineId;
  DateTime? _pendingTappedAt;
  bool _isOpening = false;

  static bool isElumiPush(Map<String, String> data) =>
      data['type'] == routineArrivedType;

  AndroidNotificationChannel routinesChannel() => AndroidNotificationChannel(
    routinesChannelId,
    appL10n.pushChannelElumiRoutines,
    importance: Importance.high,
  );

  // 로그인한 이룸이 기기인가
  bool get _isElumiSignedIn =>
      _ref.read(authSessionControllerProvider).hasSession &&
      _ref.read(localStorageProvider).isElumiDevice;

  /// 앱을 보고 있을 때 받음: 배너 없이 일과 목록만 새로 받음 (이룸이 화면을 방해하지 않음)
  void onForegroundMessage(Map<String, String> data) {
    if (!_isElumiSignedIn) return;
    _ref.refreshRoutines();
  }

  /// 누름: 기다리는 열기로 두고, 이룸이 화면이 준비됐으면 바로 엶
  void onTapped(Map<String, String> data, BuildContext? Function() readyContext) {
    if (!_isElumiSignedIn) {
      AppLogger.info('[elumi push] tap dropped : not signed in as elumi');
      return;
    }
    _pendingRoutineId = data['routineId'];
    _pendingTappedAt = DateTime.now();
    unawaited(openPending(readyContext));
  }

  /// 화면이 바뀔 때도 부름: 기다리던 열기가 있고 이룸이 화면 안이면 한 번 엶
  Future<void> openPending(BuildContext? Function() readyContext) async {
    final tappedAt = _pendingTappedAt;
    if (tappedAt == null || _isOpening) return;
    if (DateTime.now().difference(tappedAt) > _pendingOpenValidity ||
        !_isElumiSignedIn) {
      AppLogger.info('[elumi push] pending open dropped : expired or signed out');
      _clearPending();
      return;
    }
    final context = readyContext();
    if (context == null || !context.mounted) return;

    // 먼저 비워서 겹친 호출이 두 번 열지 않게 함
    final routineId = _pendingRoutineId;
    _clearPending();
    _isOpening = true;
    try {
      await _openRoutine(context, routineId);
    } catch (e, st) {
      AppLogger.error('push', e, st, {'step': 'openElumiRoutine'});
    } finally {
      _isOpening = false;
    }
  }

  // 목록 새로 받기 > 그 일과 찾기 > 상세 (못 찾거나 실패하면 이룸이 홈에 머묾)
  Future<void> _openRoutine(BuildContext context, String? routineId) async {
    _ref.refreshRoutines();
    final routines = await _ref.read(todayRoutinesProvider.future);
    if (routineId == null || !context.mounted) return;
    final matchedRoutines = routines.where((routine) => routine.id == routineId);
    if (matchedRoutines.isEmpty) {
      AppLogger.info('[elumi push] routine not in today list : stay on home');
      return;
    }
    unawaited(
      GoRouter.of(context).push<void>(
        Routes.childRoutineDetail,
        extra: matchedRoutines.first,
      ),
    );
  }

  void _clearPending() {
    _pendingRoutineId = null;
    _pendingTappedAt = null;
  }
}
