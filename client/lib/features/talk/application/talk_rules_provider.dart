import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../data/talk_repository.dart';

/// 이야기 이용 규칙 동의: 이 실행 중 확인한 결과를 기억한다
/// 상태 true = 동의 확인함 (동의는 취소되지 않으므로 true 만 기억하고, false 는 매번 서버에 묻는다)
final talkRulesAgreementProvider =
    NotifierProvider<TalkRulesAgreementNotifier, bool>(
      TalkRulesAgreementNotifier.new,
    );

/// 규칙 동의 확인·저장. 실패는 [AppFailure] 로 던지고 안내는 화면이 한다
class TalkRulesAgreementNotifier extends Notifier<bool> {
  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  bool build() => false;

  /// 동의했는가: 기억해 둔 값 > 서버 확인 순
  Future<bool> hasAgreed() async {
    if (state) return true;
    final hasAgreedOnServer = await _repository.hasAgreedRules();
    if (hasAgreedOnServer) state = true;
    return hasAgreedOnServer;
  }

  /// 서버가 동의 안 함(TALK_RULES_NOT_AGREED)으로 거절했으면 기억을 버리고 true
  /// 다른 기기에서 동의가 지워진 경우처럼 기억과 서버가 어긋날 때 규칙 시트를 다시 띄우는 신호
  bool forgetIfRejected(Object error) {
    final isRejected =
        AppFailure.of(error).server?.code == ServerErrorCode.talkRulesNotAgreed;
    if (isRejected) state = false;
    return isRejected;
  }

  /// 동의 저장
  Future<void> agree() async {
    await _repository.agreeRules();
    state = true;
  }
}
