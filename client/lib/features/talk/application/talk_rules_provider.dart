import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// 동의 저장
  Future<void> agree() async {
    await _repository.agreeRules();
    state = true;
  }
}
