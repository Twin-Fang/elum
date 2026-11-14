import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pop_in.dart';
import 'elum_button.dart';
import 'elum_error_code_text.dart';
import 'elum_secondary_button.dart';
import 'kept_text.dart';

/// 빈 상태 크기 2가지: 화면 한 장 (그림 160) · 칸 안 (그림 96, 홈 목록 · 리포트 카드)
enum ElumEmptyStateSize {
  screen(160),
  inline(96);

  const ElumEmptyStateSize(this.illustrationExtent);

  final double illustrationExtent;
}

/// 빈 상태 · 실패 · 오프라인 공통 모양: 3D 그림 (톡 튐) > 제목 > (한 줄) > (행동 1개) > (에러 코드)
/// 행동은 화면 한 장이면 채운 버튼, 칸 안이면 보조 버튼. 글은 어절 단위로 줄바꿈 (큰 글자에서도 잘리지 않음)
class ElumEmptyState extends StatelessWidget {
  const ElumEmptyState({
    super.key,
    required this.illustrationAsset,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.isActionLoading = false,
    this.errorCode,
    this.size = ElumEmptyStateSize.screen,
  });

  /// 3D 그림 PNG (AppAssets.emptyState*)
  final String illustrationAsset;
  final String title;

  /// 다음에 무엇을 하면 되는지 한 줄 (없으면 제목만)
  final String? body;

  /// 행동 글 (onAction 과 함께 있을 때만 보임)
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 행동 진행 중 (화면 한 장의 채운 버튼만 스피너)
  final bool isActionLoading;

  /// 추적용 식별자 (실패일 때)
  final String? errorCode;
  final ElumEmptyStateSize size;

  bool get _isInline => size == ElumEmptyStateSize.inline;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final typo = context.typo;
    final body = this.body;
    final actionLabel = this.actionLabel;
    final errorCode = this.errorCode;
    final titleStyle = _isInline
        ? typo.creditTitle.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)
        : typo.subtitle.copyWith(color: colors.textPrimary);
    final bodyStyle = _isInline
        ? typo.creditBody.copyWith(color: colors.textSecondary)
        : typo.promptBody.copyWith(color: colors.promptMuted);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPopIn(
          child: Image.asset(
            illustrationAsset,
            width: size.illustrationExtent.w,
            height: size.illustrationExtent.w,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(height: (_isInline ? space.xs : space.md).h),
        KeptText(title, style: titleStyle, textAlign: TextAlign.center),
        if (body != null) ...[
          SizedBox(height: (_isInline ? space.xs / 2 : space.xs).h),
          KeptText(body, style: bodyStyle, textAlign: TextAlign.center),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: (_isInline ? space.sm : space.lg).h),
          _isInline
              ? ElumSecondaryButton(label: actionLabel, onTap: onAction, isCompact: true)
              : ElumButton(label: actionLabel, onPressed: onAction, loading: isActionLoading),
        ],
        if (errorCode != null) ...[
          SizedBox(height: space.xs.h),
          ElumErrorCodeText(errorCode),
        ],
      ],
    );
  }
}
