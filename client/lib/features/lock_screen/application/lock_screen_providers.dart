import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lock_screen/lock_screen_bridge.dart';
import '../../../core/lock_screen/lock_screen_intro_rule.dart';
import '../../../core/lock_screen/lock_screen_snapshot.dart';
import '../../../core/storage/local_storage.dart';

export '../../../core/lock_screen/lock_screen_bridge.dart';
export '../../../core/lock_screen/lock_screen_snapshot.dart';

/// 띄우는 간격 선택지 (분, 0 = 화면 켤 때마다)
const List<int> lockScreenIntervalOptions = [0, 30, 60, 180];

/// 처음 켤 때 간격 (분)
const int lockScreenDefaultIntervalMinutes = 30;

/// 잠금화면 기능을 보일지 (Android 만)
final isLockScreenAvailableProvider = Provider<bool>(
  (ref) => ref.watch(lockScreenBridgeProvider).isLockScreenSupported,
);

/// 이 기기의 카드 종류: 이룸이 전용 기기면 지금 할 카드, 아니면 보호자 진행 카드
final lockScreenDeviceModeProvider = Provider<LockScreenMode>(
  (ref) => ref.watch(localStorageProvider).isElumiDevice
      ? LockScreenMode.elumi
      : LockScreenMode.guardian,
);

/// 잠금화면 상태: 네이티브 설정 + 권한
@immutable
class LockScreenState {
  const LockScreenState({
    required this.settings,
    required this.permissionStatus,
  });

  final LockScreenSettings settings;
  final LockScreenPermissionStatus permissionStatus;

  /// 켜 두었는데 필수 권한이 빠짐 > 설정 줄 "권한 필요"
  bool get isPermissionMissing =>
      settings.isEnabled && !permissionStatus.hasRequiredPermissions;
}

/// 잠금화면 설정·권한 (설정 앱에서 돌아온 뒤·권한 단계에서 refresh)
final lockScreenStateProvider =
    AsyncNotifierProvider<LockScreenStateNotifier, LockScreenState>(
      LockScreenStateNotifier.new,
    );

class LockScreenStateNotifier extends AsyncNotifier<LockScreenState> {
  LockScreenBridge get _bridge => ref.read(lockScreenBridgeProvider);

  @override
  Future<LockScreenState> build() => _load();

  Future<LockScreenState> _load() async {
    final (settings, permissionStatus) = await (
      _bridge.getSettings(),
      _bridge.getPermissionStatus(),
    ).wait;
    return LockScreenState(
      settings: settings,
      permissionStatus: permissionStatus,
    );
  }

  /// 네이티브 값 다시 읽기 (설정 앱에서 돌아온 뒤)
  Future<LockScreenState> refresh() async {
    final latest = await _load();
    state = AsyncData(latest);
    return latest;
  }

  /// 켜기: 기기 역할로 카드 종류 > 고른 간격(없으면 기존 값) > 네이티브 켜기(필수 권한 없으면 false)
  Future<bool> enable({int? selectedIntervalMinutes}) async {
    final current = state.value ?? await future;
    final isEnabled = await _bridge.enable(
      mode: ref.read(lockScreenDeviceModeProvider),
      intervalMinutes:
          selectedIntervalMinutes ?? current.settings.intervalMinutes,
    );
    await refresh();
    return isEnabled;
  }

  Future<void> disable() async {
    await _bridge.disable();
    await refresh();
  }

  Future<void> updateInterval(int intervalMinutes) async {
    await _bridge.updateInterval(intervalMinutes);
    await refresh();
  }
}

/// 소개 시트를 지금 띄울지 (네이티브 노출 기록 + 판정 규칙)
Future<bool> shouldShowLockScreenIntro(
  WidgetRef ref, {
  required bool hasElumiCompletedRoutine,
}) async {
  if (!ref.read(isLockScreenAvailableProvider)) return false;
  final bridge = ref.read(lockScreenBridgeProvider);
  final (settings, introRecord) = await (
    bridge.getSettings(),
    bridge.readIntroRecord(),
  ).wait;
  return LockScreenIntroRule.shouldShow(
    isAvailable: true,
    isEnabled: settings.isEnabled,
    hasElumiCompletedRoutine: hasElumiCompletedRoutine,
    shownCount: introRecord.shownCount,
    lastShownAt: introRecord.lastShownAt,
    now: DateTime.now(),
  );
}

/// 소개 시트 노출 기록 (띄우기 전에 기록: 닫는 방법과 무관하게 횟수 셈)
void recordLockScreenIntroShown(WidgetRef ref) =>
    unawaited(ref.read(lockScreenBridgeProvider).recordIntroShown());
