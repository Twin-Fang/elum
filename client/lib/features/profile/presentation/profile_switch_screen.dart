import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_spinner.dart';
import '../../../core/widgets/character_badge.dart';
import '../../../core/widgets/elum_check_circle.dart';
import '../../../shared/models/character.dart';
import '../../member/data/member_repository.dart';
import '../application/profile_session.dart';
import '../domain/profile_summary.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../member/application/member_providers.dart';

/// 이룸이 바꾸기 — 여러 이룸이를 돌보는 보호자(복지사 등)가 지금 볼 이룸이를 고른다.
///
/// > ⚠️ **임시 시안이다.** 시안이 없어 내 정보 이룸이 카드 모양(1736:8780)을 빌렸다.
/// > 연결된 이룸이가 둘 이상일 때만 내 정보에 이 화면으로 가는 줄이 보인다.
///
/// 고르면 [ProfileSessionNotifier.select] 가 이름·캐릭터·일과 등 **이룸이마다 다른 것을 한꺼번에**
/// 바꾼다. 이 화면은 고르는 일만 한다.
class ProfileSwitchScreen extends ConsumerStatefulWidget {
  const ProfileSwitchScreen({super.key});

  @override
  ConsumerState<ProfileSwitchScreen> createState() => _ProfileSwitchScreenState();
}

class _ProfileSwitchScreenState extends ConsumerState<ProfileSwitchScreen>
    with BusyStateMixin<ProfileSwitchScreen> {
  /// 바꾸는 동안 같은 이룸이를 두 번 고르거나 다른 이룸이를 고르지 못하게 한다.
  Future<void> _pick(ProfileSummary profile, ProfileSummary? active) async {
    if (busy) return;
    if (profile.id == active?.id) {
      context.popOrHome();
      return;
    }
    final picked = await runBusy(
      () async {
        await ref.read(profileSessionProvider.notifier).select(profile);
        return true;
      },
      key: profile.id,
    );
    // 이미 진행 중이라 실행하지 않았다.
    if (picked == null || !mounted) return;
    // 화면을 닫기 전에 잡아 둔다.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final changed = context.l10n.profileSwitchChanged;
    context.popOrHome();
    showElumToastOn(messenger, changed);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(memberProvider);
    final active = ref.watch(activeProfileProvider);

    return ElumScaffold(
      onBack: context.popOrHome,
      isBackEnabled: !busy,
      title: context.l10n.profileSwitchTitle,
      backTop: 67,
      horizontalPadding: 16,
      child: _content(async, active),
    );
  }

  Widget _content(AsyncValue<Member?> async, ProfileSummary? active) {
    if (async.hasError && async.value == null) {
      return ElumStateBody(
        child: ElumErrorView.failure(
          async.error,
          fallback: context.l10n.profileSwitchLoadFailedFallback,
          fallbackCode: 'E-PRO-LOAD',
          onRetry: () => ref.invalidate(memberProvider),
          compact: true,
        ),
      );
    }
    if (async.isLoading && async.value == null) {
      // 로딩·실패·0건은 같은 자리(본문 가운데)에 둔다 — 바뀔 때 튀지 않게.
      return const ElumStateBody.loading();
    }
    final profiles = async.value?.profiles ?? const <ProfileSummary>[];
    if (profiles.isEmpty) {
      // 서버가 목록을 못 줬거나(옛 서버·조회 실패) 연결된 이룸이가 없다. 둘 다 고를 것이 없다.
      return ElumStateBody(
        child: ElumErrorView(
          message: context.l10n.profileSwitchLoadFailedMessage,
          errorCode: 'E-PRO-LOAD',
          onRetry: () => ref.invalidate(memberProvider),
          compact: true,
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: _listTopGap.h, bottom: _listTopGap.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, p) in profiles.indexed) ...[
            if (index > 0) SizedBox(height: _cardGap.h),
            _ProfileCard(
              profile: p,
              isSelected: p.id == active?.id,
              onTap: busy ? null : () => _pick(p, active),
              isLoading: isBusy(p.id),
            ),
          ],
        ],
      ),
    );
  }

  /// 스크롤 영역 시작 > 첫 카드 (설정 화면 y=131 과 같음)
  static const _listTopGap = 24.0;

  /// 이룸이 카드 사이 (내 정보 이룸이 카드 간격과 같음)
  static const _cardGap = 16.0;
}

/// 이룸이 카드 (내 정보 이룸이 카드 결 1736:8780): 흰 판 r20 · 캐릭터 48 + 호칭, 지금 보는 이룸이는 민트 체크
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isSelected,
    required this.onTap,
    this.isLoading = false,
  });

  final ProfileSummary profile;
  final bool isSelected;
  final VoidCallback? onTap;

  /// 이 이룸이로 바꾸는 중 — 체크 자리에 스피너를 돌린다.
  final bool isLoading;

  /// 내 정보 이룸이 카드 실측 (높이 88): 왼쪽·위아래 20, 오른쪽 16, 캐릭터 48, 캐릭터 > 이름 12
  static const _padLeft = 20.0;
  static const _padRight = 16.0;
  static const _padV = 20.0;
  static const _badgeSize = 48.0;
  static const _badgeToName = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 캐릭터를 모르는 값이면 첫 캐릭터로 둔다 (화면이 죽지 않게)
    final character =
        CardCharacter.fromApiValue(profile.character) ??
        CardCharacter.values.first;

    return AppPressable(
      onTap: onTap,
      // 지금 보는 이룸이임을 낭독기가 말하게 한다 — 체크 그림만으로는 전해지지 않는다.
      semanticLabel: isSelected
          ? context.l10n.profileSwitchSelected(profile.displayName)
          : profile.displayName,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.settingsGroupBg,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _padLeft.w,
            _padV.h,
            _padRight.w,
            _padV.h,
          ),
          child: Row(
            children: [
              CharacterBadge(character: character, badgeSize: _badgeSize),
              SizedBox(width: _badgeToName.w),
              Expanded(
                child: Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.myInfoElumiName.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (isLoading)
                ElumSpinner(
                  size: ElumCheckCircle.defaultSize.w,
                  color: colors.settingsChevron,
                )
              else if (isSelected)
                const ElumCheckCircle(isChecked: true),
            ],
          ),
        ),
      ),
    );
  }
}
