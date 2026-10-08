import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../link/domain/link_status.dart';
import '../data/profile_repository.dart';

final inviteCodeControllerProvider =
    Provider<InviteCodeController>((ref) => InviteCodeController(ref));

/// 보호자 초대 코드 화면이 쓰는 저장소 호출을 모았다.
class InviteCodeController {
  InviteCodeController(this._ref);

  final Ref _ref;

  Future<Attempt<IssuedLinkCode>> issueInvite(String profileId) =>
      _ref.read(profileRepositoryProvider).issueInvite(profileId);
}
