import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../child/application/child_routine_notifier.dart';
import '../data/device_link_repository.dart';
import 'link_reset.dart';

final linkEnterControllerProvider =
    Provider<LinkEnterController>((ref) => LinkEnterController(ref));

/// 연결 암호 입력 화면이 쓰는 연결 저장소 호출을 모았다. 세션 여부는 AuthSessionController 가 준다.
class LinkEnterController {
  LinkEnterController(this._ref);

  final Ref _ref;

  /// 연결이 밖에서 끊겨 이 화면에 왔는지.
  bool get linkWasLost => _ref.read(deviceLinkRepositoryProvider).linkWasLost;

  /// 연결: 못 보낸 체크 먼저 전송 > 연결 > 성공이면 연결 전 계정 메모리 버리기
  ///
  /// 체크를 다 못 보내면 연결하지 않음 (연결 뒤에는 토큰이 바뀌어 연결 전 계정으로 보낼 길이 없음).
  /// 입력은 남는 `offline` 으로 돌려줘 인터넷이 돌아오면 다시 누르면 됨
  Future<RedeemResult> redeem(String code) async {
    if (!await _hasSentPendingChecks()) {
      return const RedeemResult(
        RedeemOutcome.offline,
        failure: AppFailure(fault: NetworkFault.offline),
      );
    }
    final result = await _ref.read(deviceLinkRepositoryProvider).redeem(code);
    if (result.outcome == RedeemOutcome.linked) _ref.forgetPreLinkAccount();
    return result;
  }

  /// 연결 전 계정의 체크 대기열이 비었는가 (보내기 시도 후, 예외는 못 보낸 것으로 봄)
  Future<bool> _hasSentPendingChecks() async {
    try {
      final isQueueEmpty = await _ref
          .read(childRoutineProvider.notifier)
          .sendPendingBeforeAccountSwitch();
      if (!isQueueEmpty) {
        AppLogger.info('[link redeem] blocked : pre-link checks not sent');
      }
      return isQueueEmpty;
    } catch (e, stack) {
      AppLogger.error('[link redeem] blocked : pre-link checks send failed', e, stack);
      return false;
    }
  }
}
