import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'elum_spinner.dart';

/// 민트 그라데이션 CTA 버튼 단일 부품 (폭 가득, 큰 글자면 높이만 늘어남): Pro 권유 버튼 · 크레딧 꾸러미 받기
///
/// 그라데이션 토큰(`proPlanCta*`)은 이 파일 밖에서 쓰지 않음 (tool/design_rules.yaml `restricted_tokens`)
class MintGradientButton extends StatelessWidget {
  const MintGradientButton({super.key, required this.label, required this.onTap, this.isLoading = false});

  final String label;

  /// null 이면 누르지 못함
  final VoidCallback? onTap;

  /// 진행 중: 글자 대신 스피너, 누르지 못함
  final bool isLoading;

  /// 최소 높이 52 · 그림자 아래 8 · 번짐 20
  static const _minHeight = 52.0;
  static const _shadowOffsetY = 8.0;
  static const _shadowBlur = 20.0;
  static const _spinnerSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null && !isLoading,
      child: AppPressable(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: _minHeight.h),
          padding: EdgeInsets.symmetric(horizontal: space.md.w, vertical: space.xs.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.proPlanCtaStart, colors.proPlanCtaEnd]),
            borderRadius: BorderRadius.circular(space.buttonRadius.r),
            boxShadow: [
              BoxShadow(
                color: colors.proPlanCtaShadow,
                offset: Offset(0, _shadowOffsetY.h),
                blurRadius: _shadowBlur.r,
              ),
            ],
          ),
          child: isLoading
              ? ElumSpinner(size: _spinnerSize.w, color: colors.proPlanCtaText)
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.typo.proPlanCtaLabel.copyWith(color: colors.proPlanCtaText),
                ),
        ),
      ),
    );
  }
}
