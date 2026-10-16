import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../domain/guardian_member.dart';

/// 내 줄의 이름 변경 버튼 키 (테스트 · 문구와 무관하게 찾기 위함)
const guardianRenameButtonKey = ValueKey('guardianRenameButton');

/// 함께하는 사람 한 줄: 이름, 나 배지, 구분 칩, (내 줄만) 이름 변경 버튼.
/// 줄 자체는 누르지 않음 (할 수 있는 일은 버튼으로만 보임)
class GuardianPersonRow extends StatelessWidget {
  const GuardianPersonRow({
    super.key,
    required this.guardian,
    required this.onRename,
    this.isRenameLoading = false,
  });

  final Guardian guardian;

  /// 내 줄이고 다른 작업 중이 아닐 때만 값이 있음 (null 이면 버튼이 흐려짐)
  final VoidCallback? onRename;

  /// 이름·구분 저장 대기 중 (버튼 자리에 스피너)
  final bool isRenameLoading;

  /// 시안 줄 높이는 최소값 (큰 글자에서는 줄이 늘어남)
  static const _minHeight = 68.0;
  static const _padStart = 18.0;
  static const _padEnd = 16.0;

  /// 글자가 커져 줄이 늘어났을 때 위아래가 붙지 않게 하는 여백
  static const _padV = 8.0;
  static const _nameToChipGap = 8.0;
  static const _chipToChipGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isCaregiver = guardian.kind == GuardianKind.caregiver;

    return Container(
      constraints: BoxConstraints(minHeight: _minHeight.h),
      padding: EdgeInsets.fromLTRB(_padStart.w, _padV.h, _padEnd.w, _padV.h),
      decoration: BoxDecoration(
        color: colors.peopleRowBg,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      ),
      child: Row(
        children: [
          // 읽기 순서: 이름 > 나 > 구분. 좁으면 칩이 다음 줄로 내려감
          Expanded(
            child: MergeSemantics(
              child: Wrap(
                spacing: _nameToChipGap.w,
                runSpacing: _chipToChipGap.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    guardian.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typo.peopleRowName.copyWith(color: colors.peopleTextPrimary),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (guardian.me) ...[
                        _PersonChip(
                          label: context.l10n.guardiansMeBadge,
                          background: colors.peopleMeBadgeBg,
                          foreground: colors.peopleMeBadgeText,
                        ),
                        SizedBox(width: _chipToChipGap.w),
                      ],
                      _PersonChip(
                        label: guardian.kind.label,
                        background: isCaregiver
                            ? colors.peopleCaregiverChipBg
                            : colors.peopleGuardianChipBg,
                        foreground: isCaregiver
                            ? colors.peopleCaregiverChipText
                            : colors.peopleGuardianChipText,
                        border: isCaregiver
                            ? colors.peopleCaregiverChipBorder
                            : colors.peopleGuardianChipBorder,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (guardian.me) ...[
            SizedBox(width: _nameToChipGap.w),
            isRenameLoading
                ? ElumSpinner(size: 20.w, color: colors.peopleChevron)
                : _RenameButton(key: guardianRenameButtonKey, onTap: onRename),
          ],
        ],
      ),
    );
  }
}

/// 이름 옆 작은 칩 (나 · 보호자 · 선생님). 테두리는 있을 때만
class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  static const _padH = 12.0;
  static const _padV = 6.0;
  static const _radius = 8.0;
  static const _borderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    // 시안은 테두리가 칩 크기 안쪽이라 테두리 두께만큼 여백을 덜어 같은 크기로 맞춤
    final inset = border == null ? 0.0 : _borderWidth;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (_padH - inset).w,
        vertical: (_padV - inset).h,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(_radius.r),
        border: border == null ? null : Border.all(color: border!, width: _borderWidth),
      ),
      child: Text(label, maxLines: 1, style: context.typo.peopleChipLabel.copyWith(color: foreground)),
    );
  }
}

/// 내 줄의 `이름 변경` 버튼. 누르면 이름·구분을 고치는 시트가 열림
class _RenameButton extends StatelessWidget {
  const _RenameButton({super.key, required this.onTap});

  final VoidCallback? onTap;

  static const _padH = 20.0;
  static const _padV = 10.0;
  static const _radius = 8.0;

  /// 손가락이 닿는 최소 높이 (보이는 버튼보다 크게)
  static const _minTouchHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: AppPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: _minTouchHeight.h),
          child: Center(
            widthFactor: 1,
            child: Opacity(
              opacity: onTap == null ? 0.5 : 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(_radius.r),
                ),
                child: Text(
                  context.l10n.guardiansRenameAction,
                  maxLines: 1,
                  style: context.typo.peopleRenameLabel.copyWith(color: colors.peopleTextPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
