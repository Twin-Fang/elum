import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/lock_screen/application/lock_screen_snapshot_providers.dart';

/// 홈(보호자 · 이룸이)이 떠 있는 동안 오늘 일과 요약을 잠금화면(Android)·홈 위젯(iOS)에 맞춤
/// 홈이 이미 오늘 목록을 보고 있어 추가 요청 없음. 같은 값이면 채널이 건너뜀
class LockScreenSnapshotSync extends ConsumerStatefulWidget {
  const LockScreenSnapshotSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockScreenSnapshotSync> createState() =>
      _LockScreenSnapshotSyncState();
}

class _LockScreenSnapshotSyncState
    extends ConsumerState<LockScreenSnapshotSync> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      lockScreenSnapshotProvider,
      (_, snapshot) => ref.read(lockScreenSnapshotPusherProvider)(snapshot),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
