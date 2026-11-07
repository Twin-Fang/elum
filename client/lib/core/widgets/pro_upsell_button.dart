import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'elum_text_link.dart';

/// 요금제 화면을 여는 버튼 모양 2개: 미리 보기 판의 주 버튼 · 화면 안 보조 안내의 글자 링크
enum ProUpsellStyle {
  /// 민트 그라데이션 버튼 (미리 보기 판 `ProTeaser`)
  filled,

  /// 밑줄 글자 (워터마크 안내 · 반복 시트처럼 다른 주 버튼 아래 보조 안내)
  link,
}

/// Pro 미리 보기 판이 할 일: 체험 기간 글 + 요금제 화면 열기 2개 (주 버튼 · `Pro 혜택 모두 보기`)
///
/// 기능 쪽이 `watchProUpsellActions` 로 만들어 넘김 (core 는 스토어 상품을 모름)
@immutable
class ProUpsellActions {
  const ProUpsellActions({
    required this.freeTrialLabel,
    required this.onStart,
    required this.onSeeAllBenefits,
  });

  /// 스토어가 체험 대상이라고 알린 기간 글 (`7일`). null 이면 `Pro 알아보기` (체험 없음 · 판매 모름)
  final String? freeTrialLabel;

  /// 주 버튼 (연 기능 혜택을 맨 위로 올린 요금제 화면)
  final VoidCallback onStart;

  /// `Pro 혜택 모두 보기` (요금제 화면)
  final VoidCallback onSeeAllBenefits;
}

/// Pro 권유 버튼 단일 부품: 문구 `7일 무료로 써 보기` / `Pro 알아보기` + 모양 2개 (#1170 · #1189)
///
/// 누르면 부르는 쪽이 `openPlanPaywall` 로 요금제 화면을 엶. 보이는 조건은 부르는 쪽 (`PlanAccess.shouldPromoteBenefit`)
/// 팝업 버튼은 팝업 부품 톤을 따름 (크레딧 부족 팝업, `ElumDialogAction`) — 문구 키만 같음
class ProUpsellButton extends StatelessWidget {
  const ProUpsellButton({
    super.key,
    required this.style,
    required this.onTap,
    this.freeTrialLabel,
  });

  final ProUpsellStyle style;

  /// null 이면 누르지 못함 (저장 중)
  final VoidCallback? onTap;

  /// 체험 기간 글. 있으면 `{기간} 무료로 써 보기` (주 버튼만)
  final String? freeTrialLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final freeTrialLabel = this.freeTrialLabel;
    return switch (style) {
      ProUpsellStyle.filled => _ProGradientButton(
        label: freeTrialLabel == null ? l10n.planLearnPro : l10n.planTryFreeTrial(freeTrialLabel),
        onTap: onTap,
      ),
      ProUpsellStyle.link => ElumTextLink(label: l10n.planLearnPro, onTap: onTap),
    };
  }
}

/// 민트 그라데이션 버튼 (폭 가득, 큰 글자면 높이만 늘어남)
class _ProGradientButton extends StatelessWidget {
  const _ProGradientButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  /// 최소 높이 52 · 그림자 아래 8 · 번짐 20
  static const _minHeight = 52.0;
  static const _shadowOffsetY = 8.0;
  static const _shadowBlur = 20.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      child: AppPressable(
        onTap: onTap,
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.typo.proPlanCtaLabel.copyWith(color: colors.proPlanCtaText),
          ),
        ),
      ),
    );
  }
}
