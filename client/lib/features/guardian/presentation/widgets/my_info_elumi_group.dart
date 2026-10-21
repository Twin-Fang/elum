import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/character_badge.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/character.dart';
import '../../../profile/application/profile_session.dart';
import '../../../profile/domain/profile_summary.dart';

/// 내정보 이룸이 카드 묶음 (시안 1736:8780): 이룸이마다 카드 하나, 누르면 이룸이 정보 고치기
///
/// 여럿이면 지금 보는 이룸이에 `보는 중` + 카드 아래 `이룸이 바꾸기` 줄 (바꾸기 입구는 여기 하나)
class MyInfoElumiGroup extends ConsumerWidget {
  const MyInfoElumiGroup({super.key, required this.profiles});

  final List<ProfileSummary> profiles;

  /// 이룸이 카드 사이 (화면 카드 간격과 같음)
  static const _cardGap = 16.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeProfileProvider)?.id;
    final hasSeveral = profiles.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, profile) in profiles.indexed) ...[
          if (index > 0) SizedBox(height: _cardGap.h),
          _ElumiCard(
            profile: profile,
            isActive: hasSeveral && profile.id == activeId,
            onTap: () => context.push(Routes.guardianElumiInfoOf(profile.id)),
          ),
        ],
        if (hasSeveral) ...[
          SizedBox(height: _cardGap.h),
          SettingsGroup(
            hasDividers: false,
            children: [
              SettingsTile(
                isInCard: true,
                label: context.l10n.guardianSettingsProfileSwitch,
                onTap: () => context.push(Routes.guardianProfileSwitch),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 이룸이 카드: 캐릭터 48 + 호칭 (+ `보는 중`) + `>`
class _ElumiCard extends StatelessWidget {
  const _ElumiCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  final ProfileSummary profile;
  final bool isActive;
  final VoidCallback onTap;

  /// 시안 실측 (카드 높이 88): 왼쪽·위아래 20, 오른쪽 16, 캐릭터 48, 캐릭터와 이름 사이 12
  static const _padLeft = 20.0;
  static const _padRight = 16.0;
  static const _padV = 20.0;
  static const _badgeSize = 48.0;
  static const _badgeToName = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    // 캐릭터를 모르는 값이면 첫 캐릭터로 둔다 (화면이 죽지 않게)
    final character =
        CardCharacter.fromApiValue(profile.character) ??
        CardCharacter.values.first;

    return AppPressable(
      onTap: onTap,
      semanticLabel: context.l10n.elumiInfoEditLabel(profile.displayName),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.settingsGroupBg,
          borderRadius: BorderRadius.circular(space.cardRadius.r),
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
              if (isActive) ...[
                Text(
                  context.l10n.guardianMyInfoActiveBadge,
                  style: context.typo.bodySmall.copyWith(
                    color: colors.creditAccentText,
                  ),
                ),
                SizedBox(width: space.xs.w),
              ],
              const SettingsCardChevron(),
            ],
          ),
        ),
      ),
    );
  }
}
