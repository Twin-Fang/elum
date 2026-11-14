import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_link_repository.dart';

/// 지금 고른 이룸이에 기기가 붙어 있는가: true 붙음 · false 없음 · null 모름 (불러오는 중 · 실패)
///
/// 다른 기능(홈 다음에 할 일 · 보내기 축하 · 온보딩)이 연결 저장소를 직접 읽지 않게 하는 통로.
/// 실패를 `없음` 으로 읽지 않음 — 이미 붙은 보호자에게 연결하라고 권하게 됨
final hasLinkedDeviceProvider = Provider.autoDispose<bool?>((ref) {
  final attempt = ref.watch(linkStatusProvider).value;
  if (attempt == null || !attempt.isOk) return null;
  return attempt.value!.hasDevice;
});

/// 연결 상태 한 번 묻기 (화면 없이): 온보딩 다음 화면 정하기용. 실패면 null
final linkedDeviceCheckProvider = Provider<Future<bool?> Function()>((ref) {
  return () async {
    final attempt = await ref.read(deviceLinkRepositoryProvider).statusResult();
    return attempt.isOk ? attempt.value!.hasDevice : null;
  };
});

/// 연결 상태를 다시 받게 비움 (연결 화면에서 돌아왔을 때)
extension LinkedDeviceRefresh on WidgetRef {
  void refreshLinkedDevice() => invalidate(linkStatusProvider);
}
