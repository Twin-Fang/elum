import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_sheet_action_row.dart';
import '../../../core/widgets/elum_spinner.dart';

/// 결제 단계 안내 한 덩이: 제목 > 설명 > (코드) > 버튼 (하나면 꽉 찬 버튼, 둘이면 시트 버튼 줄)
class PlanStateMessage extends StatelessWidget {
  const PlanStateMessage({
    super.key,
    required this.title,
    this.body,
    this.errorCode,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.isPrimaryLoading = false,
  });

  final String title;
  final String? body;

  /// 추적용 식별자 (`E-PLAN-VERIFY` · 서버 코드). null 이면 자리 없음
  final String? errorCode;

  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// 왼쪽 회색 버튼 (보통 `닫기`). null 이면 버튼 하나
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isPrimaryLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final body = this.body;
    final errorCode = this.errorCode;
    final secondaryLabel = this.secondaryLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.space.xs.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: typo.sheetStepTitle.copyWith(color: colors.sheetTitleText)),
              if (body != null) ...[
                SizedBox(height: context.space.xs.h),
                Text(body, style: typo.sheetDescription.copyWith(color: colors.sheetTitleText)),
              ],
              if (errorCode != null) ...[
                SizedBox(height: context.space.xs.h),
                Text(errorCode, style: typo.caption.copyWith(color: colors.textSecondary)),
              ],
            ],
          ),
        ),
        SizedBox(height: context.space.lg.h),
        if (secondaryLabel == null)
          ElumButton(label: primaryLabel, loading: isPrimaryLoading, onPressed: onPrimary)
        else
          ElumSheetActionRow(
            cancelLabel: secondaryLabel,
            onCancel: onSecondary,
            confirmLabel: primaryLabel,
            onConfirm: onPrimary,
            isLoading: isPrimaryLoading,
          ),
      ],
    );
  }
}

/// 기다리는 중 한 줄: 스피너 + 문구 (가격 불러오기 · 결제 확인)
class PlanProgressLine extends StatelessWidget {
  const PlanProgressLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.lg.h),
      child: Column(
        children: [
          ElumSpinner(size: 32.w, strokeWidth: 3),
          SizedBox(height: context.space.sm.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.typo.body.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
