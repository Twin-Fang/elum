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
import '../../../../shared/models/character.dart';
import '../../../profile/application/profile_session.dart';
import '../../../profile/domain/profile_summary.dart';

/// 내정보 이룸이 묶음: 줄 누르면 이룸이 바꾸기(여럿일 때), 연필 누르면 이룸이 정보 고치기 (#660)
class MyInfoElumiGroup extends ConsumerWidget {
  const MyInfoElumiGroup({super.key, required this.profiles});

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
          _ElumiRow(
            profile: profile,
            isActive: hasSeveral && profile.id == activeId,
            onTap: hasSeveral
                ? () => context.push(Routes.guardianProfileSwitch)
                : null,
            onEdit: () => context.push(Routes.guardianElumiInfoOf(profile.id)),
          ),
      ],
    );
  }
}

/// 이룸이 한 줄: 캐릭터 + 호칭 (+ `보는 중`) + 연필
class _ElumiRow extends StatelessWidget {
  const _ElumiRow({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
  });

  final ProfileSummary profile;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback onEdit;

  /// 연필 아이콘 크기 · 누름 영역 한 변
  static const _editIconSize = 22.0;
  static const _editTapSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    // 캐릭터를 모르는 값이면 첫 캐릭터로 둔다 (화면이 죽지 않게)
    final character =
        CardCharacter.fromApiValue(profile.character) ??
        CardCharacter.values.first;

    final row = Padding(
      // 오른쪽은 연필 누름 영역이 여백을 대신함
      padding: EdgeInsets.fromLTRB(
        space.md.w,
        space.sm.h,
        space.md.w - (_editTapSize - _editIconSize) / 2,
        space.sm.h,
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
          AppPressable(
            onTap: onEdit,
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: context.l10n.elumiInfoEditLabel(profile.displayName),
            child: SizedBox(
              width: _editTapSize.w,
              height: _editTapSize.w,
              child: Icon(
                Icons.edit_outlined,
                size: _editIconSize.w,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : AppPressable(onTap: onTap, child: row);
  }
}
