import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/auth_repository.dart';
import '../data/consent_repository.dart';

final consentControllerProvider =
    Provider<ConsentController>((ref) => ConsentController(ref));

/// 동의 화면이 쓰는 저장소 호출을 모았다.
class ConsentController {
  ConsentController(this._ref);

  final Ref _ref;

  /// 실패하면 [AppFailure], 성공하면 null.
  Future<AppFailure?> agree({
    required Set<String> agreedKeys,
    required String version,
  }) =>
      _ref.read(consentRepositoryProvider).agree(
            agreedKeys: agreedKeys,
            version: version,
          );

  Future<void> logout() => _ref.read(authRepositoryProvider).logout();
}
