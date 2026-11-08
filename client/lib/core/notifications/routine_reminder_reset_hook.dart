import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger/app_logger.dart';

/// 이 기기에 예약된 일과 알림 전부 취소 + 알림 목록 비우기 (알림 글에 일과 제목이 들어 있음)
typedef RoutineReminderReset = Future<void> Function();

/// 계정이 바뀌거나 끝날 때(다른 계정 로그인·로그아웃·탈퇴·이룸이 기기 연결) 부르는 연결 고리
/// 인증·연결 data 가 알림 기능을 import 하지 못하므로 core 에 두고, 실제 구현은 main 이 끼움
final routineReminderResetProvider =
    Provider<RoutineReminderReset>((ref) => () async {});

/// 일과 알림 비우기 실행 (실패는 로그만, 로그인·로그아웃·연결은 막지 않음)
Future<void> resetRoutineRemindersSafely(
  RoutineReminderReset? reset, {
  required String reason,
}) async {
  if (reset == null) return;
  try {
    await reset();
  } catch (e, stack) {
    AppLogger.error('[reminder reset] failed : $reason', e, stack);
  }
}
