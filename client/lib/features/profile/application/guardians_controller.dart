import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/profile_repository.dart';
import '../domain/guardian_member.dart';

final guardiansControllerProvider =
    Provider<GuardiansController>((ref) => GuardiansController(ref));

/// 함께하는 사람 화면이 쓰는 저장소 호출을 모았다.
class GuardiansController {
  GuardiansController(this._ref);

  final Ref _ref;

  /// 이 이룸이에서 나간다. 실패하면 [AppFailure], 성공이면 null.
  Future<AppFailure?> leave(String profileId) =>
      _ref.read(profileRepositoryProvider).leave(profileId);

  Future<Attempt<Guardian>> updateMyGuardian(
    String profileId, {
    GuardianKind? kind,
    String? displayName,
  }) => _ref
      .read(profileRepositoryProvider)
      .updateMyGuardian(profileId, kind: kind, displayName: displayName);
}
