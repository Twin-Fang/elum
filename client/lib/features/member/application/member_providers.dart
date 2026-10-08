import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../data/member_repository.dart';

/// 회원 정보. 실패하면 null이고 화면은 로컬 온보딩 값으로 fallback한다.
final memberProvider = FutureProvider<Member?>((ref) {
  // 주기 갱신이 이미 받아 둔 응답이 있으면 다시 요청하지 않고 그것을 쓴다.
  final prefetched = ref.read(memberPrefetchProvider).take();
  if (prefetched != null) return prefetched;
  return ref.watch(memberFetcherProvider)();
});

/// 회원 정보를 서버에서 받는 함수. 실패하면 null 이다 (테스트가 바꿔 끼운다).
final memberFetcherProvider = Provider<Future<Member?> Function()>((ref) {
  final dio = ref.watch(dioProvider);
  return () => MemberRepository(dio: dio).getMyInfo();
});

/// 주기 갱신이 받은 회원 정보를 [memberProvider] 가 다시 만들어질 때 한 번 꺼내 쓰게 넘기는 자리.
class MemberPrefetch {
  Member? _value;

  void put(Member member) => _value = member;

  Member? take() {
    final value = _value;
    _value = null;
    return value;
  }
}

final memberPrefetchProvider = Provider<MemberPrefetch>((ref) => MemberPrefetch());

/// 회원 정보를 **조용히** 다시 받는다 (이룸이 홈 별 · 보호자 홈 이름 등 주기 갱신용).
///
/// [MemberRepository.getMyInfo] 는 실패하면 null 이라 그냥 invalidate 하면 오프라인에서 마지막
/// 정상 값이 null 로 덮인다. 먼저 직접 받아 성공했고 화면에 쓰이는 값이 달라졌을 때만 반영한다.
/// 같은 값이면 구독자(광고 게이트·프로필 세션 등)를 다시 돌리지 않는다.
Future<void> refreshMemberQuietly(
  WidgetRef ref, {
  required bool Function() isMounted,
}) async {
  final current = ref.read(memberProvider);
  // 처음 받는 중이거나 갱신 중이면 그 응답을 기다린다 — 요청을 겹쳐 보내지 않는다.
  if (current.isLoading) return;
  final fresh = await ref.read(memberFetcherProvider)();
  if (fresh == null || !isMounted()) return;
  final before = ref.read(memberProvider).value;
  if (before != null && before.sameAs(fresh)) return;
  ref.read(memberPrefetchProvider).put(fresh);
  ref.invalidate(memberProvider);
}
