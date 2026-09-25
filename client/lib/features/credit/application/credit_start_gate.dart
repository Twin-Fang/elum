import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/credit_repository.dart';
import '../domain/credit_summary.dart';

/// 시작 전 크레딧 조회를 기다리는 상한. 누른 뒤 아무 반응 없이 이만큼 넘게
/// 멈춰 있지 않는다. 늦은 응답은 버린다 — 판정은 생성 요청에서 서버가 다시 한다.
const creditStartCheckTimeout = Duration(seconds: 3);

/// 홈 `일과 만들기` 전에 크레딧을 본다 (#407 스펙 §5).
///
/// 막아야 하면 요약을(팝업에 초기화 시각을 적으려고), 들여보내면 null 을 준다.
///
/// **조회에 실패하면 들여보낸다.** 여기는 친절한 미리 알림일 뿐 판정은 서버가
/// 생성 요청에서 다시 한다. 조회 실패로 막으면 크레딧이 남은 사람까지 못 만든다.
/// 설정 카드와 달리 매번 새로 받는다 — 방금 다른 휴대폰에서 쓴 것을 놓치지 않는다.
///
/// [creditStartCheckTimeout] 을 넘기면 기다리지 않고 들여보낸다 — 미리 알림 때문에
/// 버튼이 멈춘 것처럼 보이면 안 된다.
Future<CreditSummary?> creditBlocksRoutineStart(WidgetRef ref) async {
  try {
    final summary = await ref
        .read(creditRepositoryProvider)
        .getMine()
        .timeout(creditStartCheckTimeout);
    // 진행 중인 일과 만들기가 있으면 서버가 409 로 막는다 — 미리 막는다 (#421 ②).
    // `canStartRoutine` 은 잔액·동결만 보고 진행 중 여부는 담지 않는다.
    if (summary.enabled &&
        (!summary.canStartRoutine || summary.isGeneratingRoutine)) {
      return summary;
    }
    return null;
  } catch (e) {
    // 삼키지 않고 남긴다 — 막지 않는 것은 의도지만 실패가 묻히면 원인을 못 찾는다.
    AppLogger.error('creditBlocksRoutineStart (조회 실패 — 통과시킨다)', e);
    return null;
  }
}
