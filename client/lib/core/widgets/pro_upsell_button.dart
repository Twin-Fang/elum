import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/theme_context_ext.dart';
import 'app_pressable.dart';
import 'mint_gradient_button.dart';
import 'elum_secondary_button.dart';

/// 요금제 화면을 여는 버튼 모양 3개: 미리 보기 판의 주 버튼 · 다른 주 버튼 아래 테두리 버튼 · 화면 안 보조 안내의 작은 보조 버튼
enum ProUpsellStyle {
  /// 민트 그라데이션 버튼 (미리 보기 판 `ProTeaser`)
  filled,

  /// 민트 테두리 버튼 (크레딧 더 받기 시트: 광고 버튼보다 한 단계 낮은 무게)
  outlined,

  /// 글자 폭 보조 버튼 (워터마크 안내 · 반복 시트처럼 사실 한 줄 아래 보조 안내)
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

/// Pro 권유 버튼 단일 부품: 문구 `7일 무료로 써 보기` / `Pro 알아보기` + 모양 3개 (#1170 · #1189)
///
/// 누르면 부르는 쪽이 `openPlanPaywall` 로 요금제 화면을 엶. 보이는 조건은 부르는 쪽 (`PlanAccess.shouldPromoteBenefit`)
class ProUpsellButton extends StatelessWidget {
  const ProUpsellButton({
    super.key,
    required this.style,
    required this.onTap,
    this.freeTrialLabel,
    this.label,
  });

  final ProUpsellStyle style;

  /// null 이면 누르지 못함 (저장 중)
  final VoidCallback? onTap;

  /// 체험 기간 글. 있으면 `{기간} 무료로 써 보기` (주 버튼 · 테두리 버튼)
  final String? freeTrialLabel;

  /// 기능 다음 단계를 말하는 문구 (`다음 주 리포트도 받아 보기`). 있으면 체험·`Pro 알아보기` 문구 대신 씀
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final freeTrialLabel = this.freeTrialLabel;
    final startLabel = label ?? (freeTrialLabel == null ? l10n.planLearnPro : l10n.planTryFreeTrial(freeTrialLabel));
    return switch (style) {
      ProUpsellStyle.filled => MintGradientButton(label: startLabel, onTap: onTap),
      ProUpsellStyle.outlined => _OutlinedUpsellButton(label: startLabel, onTap: onTap),
      ProUpsellStyle.link => ElumSecondaryButton(label: label ?? l10n.planLearnPro, onTap: onTap, isCompact: true),
    };
  }
}

/// 민트 테두리 버튼 (폭 가득, 큰 글자면 높이만 늘어남)
class _OutlinedUpsellButton extends StatelessWidget {
  const _OutlinedUpsellButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  /// 최소 높이 52 (민트 버튼과 같음) · 테두리 2
  static const _minHeight = 52.0;
  static const _borderWidth = 2.0;

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
            color: colors.surface,
            borderRadius: BorderRadius.circular(space.buttonRadius.r),
            border: Border.all(color: colors.proPlanProCardRing, width: _borderWidth.w),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: context.typo.proPlanCtaLabel.copyWith(color: colors.textPrimary),
          ),
        ),
      ),
    );
  }
}
