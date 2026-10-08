import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../data/device_link_repository.dart';
import '../domain/link_status.dart';

final linkCodeControllerProvider =
    Provider<LinkCodeController>((ref) => LinkCodeController(ref));

/// 연결 암호 발급 화면이 쓰는 저장소 호출을 모았다.
class LinkCodeController {
  LinkCodeController(this._ref);

  final Ref _ref;

  /// 암호를 만든다. [withBaseline] 이면 만드는 것과 함께 지금 붙어 있는 휴대폰 목록도 조회한다.
  Future<(Attempt<IssuedLinkCode>, Attempt<LinkStatus>?)> issue({
    required bool withBaseline,
  }) async {
    final repo = _ref.read(deviceLinkRepositoryProvider);
    final baseline = withBaseline ? repo.statusResult() : null;
    final attempt = await repo.issue();
    final before = await baseline;
    return (attempt, before);
  }

  Future<Attempt<LinkStatus>> statusResult() =>
      _ref.read(deviceLinkRepositoryProvider).statusResult();
}
