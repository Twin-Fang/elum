import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_link_repository.dart';

final linkStatusControllerProvider =
    Provider<LinkStatusController>((ref) => LinkStatusController(ref));

/// 연결 상태 화면이 쓰는 연결 저장소 호출을 모았다.
class LinkStatusController {
  LinkStatusController(this._ref);

  final Ref _ref;

  Future<RevokeResult> revoke(String linkId) =>
      _ref.read(deviceLinkRepositoryProvider).revoke(linkId);
}
