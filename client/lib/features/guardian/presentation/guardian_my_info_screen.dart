import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/character_badge.dart';
import '../../../core/widgets/settings_group.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../shared/models/character.dart';
import '../../member/application/member_providers.dart';
import '../../profile/application/profile_session.dart';
import '../../profile/domain/profile_summary.dart';
import 'widgets/ai_credit_card.dart';

/// 하단 바 내정보 칸의 첫 화면: 보호자 프로필 > 이룸이 > AI 크레딧(사용 내역 링크 포함) > 바로가기 (#817)
///
/// 설정은 오른쪽 위 아이콘으로만 들어간다. 이룸이가 여러 명이어도(교육 라이선스) 같은 구조로 늘어난다.
/// 회원 정보를 못 받으면 이룸이 영역만 빠지고 나머지는 그대로 뜬다 (화면이 회원 정보에 막히지 않게).
class GuardianMyInfoScreen extends ConsumerWidget {
  const GuardianMyInfoScreen({super.key});

  /// 카드 묶음 사이 간격 (설정 화면과 같다)
  static const _groupGap = 16.0;

  /// 설정 아이콘 크기 · 누름 영역 한 변
  static const _gearIconSize = 26.0;
  static const _gearTapSize = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final colors = context.colors;
    final profiles = ref.watch(
      memberProvider.select((member) => member.value?.profiles),
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 제목 줄 (제목 | 설정 아이콘)
            Padding(
              padding: EdgeInsets.fromLTRB(
                space.screenH.w,
                space.sm.h,
                space.screenH.w - (_gearTapSize - _gearIconSize) / 2,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.guardianTabMe,
                      style: context.typo.greeting.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  AppPressable(
                    onTap: () => context.push(Routes.guardianSettings),
                    scaleDown: AppPressable.scaleIcon,
                    semanticLabel: context.l10n.guardianSettingsTitle,
                    child: SizedBox(
                      width: _gearTapSize.w,
                      height: _gearTapSize.w,
                      child: Icon(
                        Icons.settings_outlined,
                        size: _gearIconSize.w,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  space.screenH.w,
                  space.md.h,
                  space.screenH.w,
                  space.lg.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(profileCount: profiles?.length),
                    // 이룸이 목록: 회원 정보를 받았고 1명 이상일 때만
                    if (profiles != null && profiles.isNotEmpty) ...[
                      SizedBox(height: _groupGap.h),
                      _ChildrenGroup(profiles: profiles),
                    ],
                    SizedBox(height: _groupGap.h),
                    // 이번 주 AI 생성: 꺼져 있으면 자리도 없고, 아래 간격은 카드가 가진다
                    const AiCreditCard(),
                    SettingsGroup(
                      hasDividers: false,
                      children: [
                        SettingsTile(
                          isInCard: true,
                          label: context.l10n.guardianSettingsPeople,
                          onTap: () => context.push(Routes.guardianPeople),
                        ),
                        SettingsTile(
                          isInCard: true,
                          label: context.l10n.guardianSettingsDrafts,
                          onTap: () => context.push(Routes.guardianDrafts),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 보호자 프로필 카드: 기본 아이콘 + 이름 + 연결된 이룸이 수
///
/// 서버에 보호자 이름이 없어 "보호자"로 둔다. [profileCount] 가 null 이면(회원 정보 못 받음) 안내 줄을 뺀다.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profileCount});

  final int? profileCount;

  static const _avatarSize = 56.0;
  static const _avatarIconSize = 32.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final count = profileCount;
    final summary = switch (count) {
      null => null,
      0 => context.l10n.guardianMyInfoNoLinked,
      _ => context.l10n.guardianMyInfoLinkedCount(count),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.settingsGroupBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(space.md.w),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.creditNoticeBg,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: _avatarSize.w,
                height: _avatarSize.w,
                child: Icon(
                  Icons.person_rounded,
                  size: _avatarIconSize.w,
                  color: colors.creditAccentText,
                ),
              ),
            ),
            SizedBox(width: space.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.guardianMyInfoProfileName,
                    style: context.typo.sectionTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (summary != null)
                    Text(
                      summary,
                      style: context.typo.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 연결된 이룸이 목록. 둘 이상이면 줄을 눌러 이룸이 바꾸기로 가고, 지금 보는 이룸이에 `보는 중`을 붙인다.
class _ChildrenGroup extends ConsumerWidget {
  const _ChildrenGroup({required this.profiles});

  final List<ProfileSummary> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(activeProfileProvider)?.id;
    final hasSeveral = profiles.length > 1;

    return SettingsGroup(
      header: context.l10n.guardianMyInfoChildrenHeader,
      hasDividers: false,
      children: [
        for (final profile in profiles)
          _ChildRow(
            profile: profile,
            isActive: hasSeveral && profile.id == activeId,
            onTap: hasSeveral
                ? () => context.push(Routes.guardianProfileSwitch)
                : null,
          ),
      ],
    );
  }
}

/// 이룸이 한 줄: 캐릭터 + 호칭 (+ `보는 중`)
class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.profile,
    required this.isActive,
    required this.onTap,
  });

  final ProfileSummary profile;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    // 캐릭터를 모르는 값이면 첫 캐릭터로 둔다 (화면이 죽지 않게)
    final character =
        CardCharacter.fromApiValue(profile.character) ??
        CardCharacter.values.first;

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: space.md.w,
        vertical: space.sm.h,
      ),
      child: Row(
        children: [
          CharacterBadge(character: character),
          SizedBox(width: space.md.w),
          Expanded(
            child: Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typo.sectionTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
          if (isActive)
            Text(
              context.l10n.guardianMyInfoActiveBadge,
              style: context.typo.bodySmall.copyWith(
                color: colors.creditAccentText,
              ),
            ),
        ],
      ),
    );
    return onTap == null ? row : AppPressable(onTap: onTap, child: row);
  }
}
