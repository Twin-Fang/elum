import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import 'library_entries.dart';
import 'routine_library_controller.dart';

/// 일과관리 칸 들어가기 전(build 밖): 화면이 처음 읽을 목록 provider 미리 읽기 (#987)
///
/// 다른 칸에 있는 동안 무효화된 목록 > 일과관리 build 가 다시 계산 > 멈춘 홈 provider 에 갱신 예약 >
/// build 중 setState 경고 (riverpod 3.3.2, 3.4.0 에서 고침). 칸 누르기·버튼 처리 안에서 먼저 계산해 둔다.
/// 받아 둔 값이면 아무 일도 하지 않음. riverpod 3.4 이상으로 올리면 지워도 됨.
void readRoutineManageSourcesBeforeEntering(ProviderContainer container) {
  try {
    // RoutineManageScreen.build 가 watch 하는 순서 그대로 (격자 > 오늘 보낸 표시)
    container
      ..read(libraryEntriesProvider)
      ..read(sentTodaySourceIdsProvider);
  } catch (error, stackTrace) {
    // 미리 읽기만 실패 > 칸 이동은 그대로, 화면이 build 에서 다시 읽는다
    AppLogger.error('[routine manage] pre-read failed', error, stackTrace);
  }
}
