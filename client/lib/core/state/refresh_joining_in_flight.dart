import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FutureProvider 다시 받기: 받는 중이면 그 결과를 기다림(새 요청 없음), 아니면 새로 받기
///
/// 주기 갱신의 "받는 중이면 건너뜀"과 같은 기준(`isLoading`) — 어느 쪽이 먼저 시작해도 요청은 한 번.
/// 실패하면 던진다. 직전 값은 provider 에 그대로 남는다.
Future<T> refreshJoiningInFlight<T>(WidgetRef ref, FutureProvider<T> provider) {
  if (ref.read(provider).isLoading) return ref.read(provider.future);
  return ref.refresh(provider.future);
}
