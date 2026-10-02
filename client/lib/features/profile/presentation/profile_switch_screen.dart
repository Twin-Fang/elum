import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../guardian/data/member_repository.dart';
import '../../guardian/data/routine_repository.dart' show memberProvider;
import '../application/profile_session.dart';
import '../domain/profile_summary.dart';
import '../../../core/router/pop_or_home.dart';

/// 이룸이 바꾸기 — 여러 이룸이를 돌보는 보호자(복지사 등)가 지금 볼 이룸이를 고른다 (다중 보호자 #362).
///
/// > ⚠️ **임시 시안이다.** 시안이 없어 설정 화면의 줄 모양(`SettingsTile` 과 같은 높이·여백)을
/// > 빌렸다. 연결된 이룸이가 둘 이상일 때만 설정에 이 화면으로 가는 줄이 보인다.
///
/// 고르면 [ProfileSessionNotifier.select] 가 이름·캐릭터·일과 등 **이룸이마다 다른 것을 한꺼번에**
/// 바꾼다. 이 화면은 고르는 일만 한다.
class ProfileSwitchScreen extends ConsumerStatefulWidget {
  const ProfileSwitchScreen({super.key});

  @override
  ConsumerState<ProfileSwitchScreen> createState() => _ProfileSwitchScreenState();
}

class _ProfileSwitchScreenState extends ConsumerState<ProfileSwitchScreen> {
  /// 바꾸는 중. 같은 이룸이를 두 번 고르거나 바꾸는 동안 다른 이룸이를 고르지 못하게 한다.
  bool _busy = false;

  Future<void> _pick(ProfileSummary profile, ProfileSummary? active) async {
    if (_busy) return;
    if (profile.id == active?.id) {
      context.popOrHome();
      return;
    }
    setState(() => _busy = true);
    await ref.read(profileSessionProvider.notifier).select(profile);
    if (!mounted) return;
    // 화면을 닫기 전에 잡아 둔다.
    final messenger = ScaffoldMessenger.of(context);
    context.popOrHome();
    messenger.showSnackBar(const SnackBar(content: Text('이룸이를 바꿨어요')));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(memberProvider);
    final active = ref.watch(activeProfileProvider);

    return ElumScaffold(
      onBack: _busy ? null : context.popOrHome,
      title: '이룸이 바꾸기',
      backTop: 67,
      horizontalPadding: 16,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 40.h),
          child: _content(async, active),
        ),
      ),
    );
  }

  Widget _content(AsyncValue<Member?> async, ProfileSummary? active) {
    if (async.hasError && async.value == null) {
      return ElumErrorView.failure(
        async.error,
        fallback: '이룸이 목록을 불러오지 못했어요',
        fallbackCode: 'E-PRO-LOAD',
        onRetry: () => ref.invalidate(memberProvider),
        compact: true,
      );
    }
    if (async.isLoading && async.value == null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final profiles = async.value?.profiles ?? const <ProfileSummary>[];
    if (profiles.isEmpty) {
      // 서버가 목록을 못 줬거나(옛 서버·조회 실패) 연결된 이룸이가 없다. 둘 다 고를 것이 없다.
      return ElumErrorView(
        message: '이룸이 목록을 불러오지 못했어요',
        errorCode: 'E-PRO-LOAD',
        onRetry: () => ref.invalidate(memberProvider),
        compact: true,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final p in profiles)
          _ProfileTile(
            profile: p,
            selected: p.id == active?.id,
            onTap: _busy ? null : () => _pick(p, active),
          ),
      ],
    );
  }
}

/// 이룸이 한 줄. 지금 보는 이룸이는 오른쪽에 체크가 붙는다.
class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final ProfileSummary profile;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      // 지금 보는 이룸이임을 낭독기가 말하게 한다 — 체크 그림만으로는 전해지지 않는다.
      semanticLabel: selected ? '${profile.displayName}, 지금 보는 이룸이' : profile.displayName,
      child: SizedBox(
        height: SettingsTile.height.h,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: SettingsTile.padH.w),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.settingsTileLabel.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 24.w, color: colors.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
