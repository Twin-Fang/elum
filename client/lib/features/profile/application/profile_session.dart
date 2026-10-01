import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/session_expiry.dart';
import '../../../core/storage/local_storage.dart';
import '../../guardian/application/routine_notifier.dart';
import '../../guardian/data/member_repository.dart';
import '../../guardian/data/routine_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../../auth/domain/app_role.dart';
import '../data/profile_repository.dart';
import '../domain/profile_summary.dart';

/// 보호자가 지금 보고 있는 이룸이 (다중 보호자 #362).
@immutable
class ProfileSession {
  const ProfileSession({this.selectedId, this.noProfile = false});

  /// 고른 이룸이 id. 모든 요청에 `X-Profile-Id` 로 실린다. 없으면 서버가 첫 이룸이를 쓴다.
  final String? selectedId;

  /// 연결된 이룸이가 하나도 없다 (마지막 보호자로 나갔거나 서버가 알렸다 · E29).
  /// 앱은 이룸이 등록(온보딩)으로 보낸다.
  final bool noProfile;

  @override
  bool operator ==(Object other) =>
      other is ProfileSession &&
      other.selectedId == selectedId &&
      other.noProfile == noProfile;

  @override
  int get hashCode => Object.hash(selectedId, noProfile);
}

/// 이룸이에서 나간 뒤 지금 보는 이룸이가 어떻게 됐는가.
enum LeftOutcome {
  /// 지금 보던 이룸이에서 나가 남은 이룸이로 옮겼다.
  switched,

  /// 다른 이룸이에서 나갔다. 지금 보는 이룸이는 그대로다.
  stayed,

  /// 연결된 이룸이가 하나도 남지 않았다 — 이룸이 등록으로 보낸다 (E29).
  none,
}

final profileSessionProvider =
    NotifierProvider<ProfileSessionNotifier, ProfileSession>(
      ProfileSessionNotifier.new,
    );

/// 고른 이룸이를 들고 있고, **이룸이마다 다른 값을 한 곳에서 맞춘다.**
///
/// 이룸이를 바꾸는 길은 여럿이다 — 직접 고르기·초대로 합류·나가기·다른 휴대폰에서 잃기.
/// 길마다 "무엇을 다시 받아야 하는가"를 따로 적으면 하나를 빠뜨려 **다른 이룸이의 일과가
/// 남는다.** 그래서 전부 [_refreshScoped] 한 곳을 지난다.
///
/// 이룸이 휴대폰에서는 아무것도 하지 않는다 — 이룸이를 고르는 일은 보호자의 몫이고, 이룸이
/// 휴대폰은 연결된 이룸이 하나만 본다.
class ProfileSessionNotifier extends Notifier<ProfileSession> {
  LocalStorage? get _storage {
    try {
      return ref.read(localStorageProvider);
    } catch (_) {
      // 저장소를 올리지 않은 곳(일부 테스트)에서도 화면은 뜬다.
      return null;
    }
  }

  bool get _isElumi => _storage?.isElumiDevice ?? false;

  @override
  ProfileSession build() {
    // 서버 목록이 들어올 때마다 고른 이룸이를 맞춘다. 이 상태를 만드는 순간 회원 정보 조회도
    // 함께 시작된다 — 목록은 거기서만 온다.
    ref.listen<AsyncValue<Member?>>(memberProvider, (_, next) {
      // 다시 받는 중에는 **직전 값이 그대로 실려 온다.** 그것으로 맞추면 방금 바꾼 선택이
      // 옛 목록으로 되돌아간다 — 새 응답이 들어왔을 때만 본다.
      if (next.isLoading) return;
      final member = next.value;
      if (member != null) _reconcile(member);
    });

    // 이미 받아 둔 회원 정보가 있으면 구독만으로는 알림이 오지 않는다. build 가 끝난 뒤에
    // 한 번 맞춘다 — build 안에서 상태를 읽으면 아직 만들어지지 않았다고 막힌다.
    final cached = ref.read(memberProvider);
    final cachedMember = cached.isLoading ? null : cached.value;
    if (cachedMember != null) {
      Future<void>.microtask(() {
        if (ref.mounted) _reconcile(cachedMember);
      });
    }

    // 로그인이 풀리면 고른 이룸이를 잊는다. 다른 계정이 이어 들어와도 옛 id 가 헤더에 남지 않게.
    ref.listen<int>(sessionExpiryProvider, (previous, next) {
      if (previous == null || next <= previous) return;
      final storage = _storage;
      if (storage != null) {
        storage.clearSelectedProfileId().catchError((Object e) {
          debugPrint('[profile] 세션 종료 뒤 선택 정리 실패: $e');
        });
      }
      state = const ProfileSession();
    });

    return ProfileSession(selectedId: _storage?.selectedProfileId);
  }

  /// 서버가 준 목록에 맞춰 고른 이룸이를 정한다.
  ///
  /// - 비어 있으면 이룸이 없음이다.
  /// - 고른 적이 없거나 목록에 없으면 **첫 이룸이**다 — 헤더가 없을 때 서버가 쓰는 것과 같다.
  /// - 그 이룸이의 이름·캐릭터·그림 방식·도움 목표를 로컬에 맞춘다 (E44).
  Future<void> _reconcile(Member member) async {
    if (_isElumi) return;
    // 옛 서버는 목록을 주지 않는다. 모르는 것을 "없다"로 읽지 않는다 (E36).
    if (!member.profilesKnown) return;
    final profiles = member.profiles;

    if (profiles.isEmpty) {
      // 새 서버가 "연결된 이룸이가 없다"고 말했다 (E29). 이미 처리했으면 다시 하지 않는다 —
      // 처리하며 회원 정보를 다시 받으므로 여기서 또 처리하면 끝나지 않는다.
      if (!state.noProfile) await _enterNoProfile();
      return;
    }

    final current = state.selectedId;
    final target = profiles.firstWhere(
      (p) => p.id == current,
      orElse: () => profiles.first,
    );
    if (target.id != current) {
      await _storage?.setSelectedProfileId(target.id);
    }
    if (!ref.mounted) return;
    state = ProfileSession(selectedId: target.id);

    // 회원 정보의 당사자 항목은 헤더가 짚은 이룸이다 — 도움 목표는 여기서만 온다.
    await ref
        .read(onboardingProvider.notifier)
        .applyServerProfile(target, goals: member.supportGoals);
  }

  /// 이룸이를 바꾼다. 같은 이룸이면 아무것도 하지 않는다.
  Future<void> select(ProfileSummary profile) async {
    if (state.selectedId == profile.id) return;
    await _storage?.setSelectedProfileId(profile.id);
    state = ProfileSession(selectedId: profile.id);
    // 목록을 기다리지 않고 이름·캐릭터를 먼저 맞춘다 — 홈이 잠깐이라도 옛 이름을 말하지 않게.
    // 도움 목표는 비운다: 이 이룸이의 값은 회원 정보가 와야 알고, 그 사이 일과를 만들면
    // 앞 이룸이의 목표가 AI 로 가는 것보다 비어 있는 편이 낫다.
    await ref
        .read(onboardingProvider.notifier)
        .applyServerProfile(profile, goals: const []);
    await _refreshScoped();
  }

  /// 초대 코드로 이룸이에 합류했다 (E6).
  ///
  /// 온보딩(이룸이 등록)을 건너뛰므로 **마친 것으로 둔다** — 안 그러면 라우터가 이름 입력으로
  /// 되돌린다. 합류한 이룸이를 고르고, 서버가 지운 빈 이룸이는 [ProfileJoin.removedProfileIds]
  /// 로 알려 주지만 앱이 들고 있던 선택은 합류한 이룸이로 바뀌므로 따로 할 일이 없다.
  Future<void> joined(ProfileJoin join) async {
    final storage = _storage;
    try {
      await storage?.setOnboardingCompleted(true);
      await storage?.setSelectedRole(AppRole.guardian.storageValue);
      await storage?.setSelectedProfileId(join.profile.id);
    } catch (e) {
      debugPrint('[profile] 합류 저장 실패, 서버에는 합류했다: $e');
    }
    state = ProfileSession(selectedId: join.profile.id);
    await ref.read(onboardingProvider.notifier).applyServerProfile(join.profile);
    await _refreshScoped();
  }

  /// 이 이룸이에서 나갔다 (서버가 받아 줬다).
  ///
  /// 나가기 전에 지우는 것은 없다 — 서버가 성공을 알린 뒤에만 이 메서드가 불린다.
  Future<LeftOutcome> left(String profileId) async {
    var member = ref.read(memberProvider).value;
    if (member == null || !member.profilesKnown) {
      // 목록을 모른다(조회 실패·옛 서버). 한 번 더 받아 본다.
      ref.invalidate(memberProvider);
      member = await ref.read(memberProvider.future);
    }
    if (member == null || !member.profilesKnown) {
      // 그래도 모르면 **없다고 읽지 않는다** — 다른 이룸이가 남아 있는데 이룸이 값을 지우고
      // 온보딩으로 보내면 되돌릴 수 없다. 나간 이룸이만 고르지 않은 것으로 하고 다음에 받는 목록이
      // 새로 정해 준다.
      if (state.selectedId == profileId) {
        state = const ProfileSession();
        await _storage?.clearSelectedProfileId();
      }
      await _refreshScoped();
      return LeftOutcome.stayed;
    }

    final remaining = member.profiles.where((p) => p.id != profileId).toList();

    if (remaining.isEmpty) {
      await _enterNoProfile();
      return LeftOutcome.none;
    }
    if (state.selectedId == profileId) {
      await select(remaining.first);
      return LeftOutcome.switched;
    }
    await _refreshScoped();
    return LeftOutcome.stayed;
  }

  /// 요청이 "이 이룸이는 볼 수 없다"고 돌아왔다 — 다른 휴대폰에서 나갔거나 지워졌다.
  ///
  /// 선택을 풀고 목록을 다시 받는다. 목록이 첫 이룸이를 정해 준다 ([_reconcile]).
  /// 여러 요청이 한꺼번에 같은 실패를 받으면 이 메서드가 여러 번 불린다 — **지금 고른 이룸이를
  /// 잃은 경우에만** 움직여 한 번만 처리한다.
  void lost(String profileId) {
    if (state.selectedId != profileId) return;
    state = const ProfileSession();
    _storage?.clearSelectedProfileId().catchError((Object e) {
      debugPrint('[profile] 잃은 이룸이 선택 정리 실패: $e');
    });
    _refreshScoped();
  }

  /// 서버가 "연결된 이룸이가 없다"고 알렸다 (E29). 이미 알았으면 다시 처리하지 않는다.
  void markNoProfile() {
    if (_isElumi || state.noProfile) return;
    _enterNoProfile();
  }

  /// 이룸이 없음 상태로 들어간다 — 이룸이 값을 비우고 온보딩 미완료로 돌린다.
  ///
  /// 비밀암호는 지킨다. 이 휴대폰에서 이룸이 화면 → 보호자 화면으로 넘어올 때 쓰는 것이라
  /// 이룸이와 무관하다 (E45).
  Future<void> _enterNoProfile() async {
    final storage = _storage;
    if (storage != null) {
      try {
        final pin = await storage.getPin();
        await storage.clearChildProfile();
        if (pin != null) await storage.setPin(pin);
      } catch (e) {
        debugPrint('[profile] 이룸이 없음 정리 실패: $e');
      }
    }
    state = const ProfileSession(noProfile: true);
    ref.read(onboardingProvider.notifier).resetProfile();
    await _refreshScoped();
  }

  /// 이룸이마다 다른 것을 전부 다시 받게 한다.
  ///
  /// 일과 목록 셋·추천·회원 정보를 무효화하고, 만들던 일과 입력과 오프라인 캐시를 비운다.
  /// **한 곳만 빠져도 다른 이룸이의 것이 남는다** — 새 이룸이별 데이터가 생기면 여기에 더한다.
  Future<void> _refreshScoped() async {
    AppLogger.notifierCall('ProfileSessionNotifier', 'refreshScoped', {
      'selected': state.selectedId ?? '-',
    });
    try {
      await _storage?.clearCachedTodayRoutines();
    } catch (e) {
      debugPrint('[profile] 오늘 일과 캐시 정리 실패: $e');
    }
    ref.read(routineFlowProvider.notifier).reset();
    // 이룸이 화면의 체크 기록·서버 반영 대기열(childRoutineProvider)은 비우지 않는다 — 아직 서버에
    // 못 보낸 체크가 대기열에 있을 수 있고, 메모리만 비우면 앱을 다시 켜기 전까지 다시 보내지 않는다.
    ref.refreshRoutines();
    ref.invalidate(routineSuggestionsProvider);
    ref.invalidate(memberProvider);
  }
}

/// 지금 보고 있는 이룸이를 정한다 — 고른 것이 목록에 있으면 그것, 없으면 첫 이룸이.
///
/// 회원 정보가 아직 없거나(조회 실패) 목록이 비어 있어도 **고른 id 가 있으면 그것을 돌려준다.**
/// 화면이 서버 한 번 실패했다고 이룸이를 잃으면 안 된다. 아무것도 모르면 null 이다.
ProfileSummary? pickActiveProfile(Member? member, String? selectedId) {
  final profiles = member?.profiles ?? const <ProfileSummary>[];
  for (final p in profiles) {
    if (p.id == selectedId) return p;
  }
  if (selectedId != null && selectedId.isNotEmpty && profiles.isEmpty) {
    return ProfileSummary(id: selectedId);
  }
  return profiles.firstOrNull;
}

/// 화면이 쓰는 "지금 보는 이룸이". 이름·캐릭터를 함께 알아야 하는 곳에서 구독한다.
final activeProfileProvider = Provider<ProfileSummary?>((ref) {
  final member = ref.watch(memberProvider).value;
  final selected = ref.watch(profileSessionProvider.select((s) => s.selectedId));
  return pickActiveProfile(member, selected);
});
