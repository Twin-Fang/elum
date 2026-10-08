import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/profile_repository.dart';

final inviteEnterControllerProvider =
    Provider<InviteEnterController>((ref) => InviteEnterController(ref));

/// 초대 코드 입력 화면이 쓰는 프로필 저장소 호출을 모았다.
class InviteEnterController {
  InviteEnterController(this._ref);

  final Ref _ref;

  Future<Attempt<ProfileJoin>> redeemInvite(String code) =>
      _ref.read(profileRepositoryProvider).redeemInvite(code);
}
