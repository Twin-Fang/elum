import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/text/keep_words.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_check_circle.dart';
import '../../../../core/widgets/elum_label_chip.dart';
import '../../../../core/widgets/elum_secondary_button.dart';

/// 권한 단계 카드 하나: 체크 > 제목 · 필수/권장 칩 > 이유 한 줄 > (지금 단계만) 설정 열기 · 건너뛰기 · 추가했어요
/// 지금 단계는 민트 테두리로 강조, 끝난 단계는 체크만 켜짐
class LockScreenPermissionStepCard extends StatelessWidget {
  const LockScreenPermissionStepCard({
    super.key,
    required this.title,
    required this.reason,
    required this.isRequired,
    required this.isDone,
    required this.isCurrent,
    required this.onOpenSettings,
    this.onSkip,
    this.pathHint,
    this.onConfirmDone,
  });

  final String title;
  final String reason;
  final bool isRequired;
  final bool isDone;
  final bool isCurrent;
  final VoidCallback onOpenSettings;

  /// 권장 단계만 (필수는 null)
  final VoidCallback? onSkip;

  /// 설정에서 돌아온 뒤 보여 줄 경로 안내 (결과를 읽을 수 없는 삼성 절전 예외)
  final String? pathHint;

  /// "추가했어요" (결과를 읽을 수 없는 단계, 설정을 다녀온 뒤에만)
  final VoidCallback? onConfirmDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final pathHint = this.pathHint;
    final onSkip = this.onSkip;
    final onConfirmDone = this.onConfirmDone;
    return Container(
      padding: EdgeInsets.all(space.md.w),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
        border: Border.all(
          color: isCurrent ? colors.highlightBorder : colors.border,
          width: isCurrent ? space.selectedBorderWidth : space.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElumCheckCircle(isChecked: isDone),
          SizedBox(width: space.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: space.xs.w,
                  runSpacing: space.xs.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: typo.creditTitle.copyWith(color: colors.textPrimary),
                    ),
                    ElumLabelChip(
                      label: isRequired
                          ? context.l10n.lockScreenPermissionRequired
                          : context.l10n.lockScreenPermissionRecommended,
                      background: isRequired
                          ? colors.infoHighlightMintFill
                          : colors.buttonNeutral,
                      foreground: isRequired
                          ? colors.infoHighlightMintAccent
                          : colors.buttonNeutralText,
                    ),
                  ],
                ),
                SizedBox(height: space.xs.h),
                Text(
                  keepWords(reason, locale: context.appLocale),
                  semanticsLabel: reason,
                  style: typo.creditBody.copyWith(color: colors.textSecondary),
                ),
                if (isCurrent && !isDone) ...[
                  if (pathHint != null && onConfirmDone != null) ...[
                    SizedBox(height: space.xs.h),
                    Text(
                      keepWords(pathHint, locale: context.appLocale),
                      semanticsLabel: pathHint,
                      style: typo.creditBody.copyWith(color: colors.textPrimary),
                    ),
                  ],
                  SizedBox(height: space.sm.h),
                  Wrap(
                    spacing: space.xs.w,
                    runSpacing: space.xs.h,
                    children: [
                      if (onConfirmDone != null)
                        ElumSecondaryButton(
                          label: context.l10n.lockScreenPermissionConfirmDone,
                          onTap: onConfirmDone,
                          isCompact: true,
                        ),
                      ElumSecondaryButton(
                        label: context.l10n.lockScreenPermissionOpenSettings,
                        onTap: onOpenSettings,
                        isCompact: true,
                      ),
                      if (onSkip != null)
                        ElumSecondaryButton(
                          label: context.l10n.lockScreenPermissionSkip,
                          onTap: onSkip,
                          isCompact: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
