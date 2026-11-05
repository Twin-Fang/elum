import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// 연결 > 성공이면 연결 전 계정 메모리 버리기 (이룸이 홈이 저장소의 새 이름부터 읽게)
  Future<RedeemResult> redeem(String code) async {
    final result = await _ref.read(deviceLinkRepositoryProvider).redeem(code);
    if (result.outcome == RedeemOutcome.linked) _ref.forgetPreLinkAccount();
    return result;
  }
}
