import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/text/keep_words.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_text_link.dart';
import '../application/plan_offer_labels.dart';
import '../domain/plan_catalog.dart';

/// 바닥 고정 결제 (#1189 시안 A): 주 버튼 (체험 대상 `7일 무료로 시작하기` / `구독 시작하기`) > 작은 한 줄 (스토어 값)
///
/// 상품을 못 불러왔으면 버튼만 꺼진 채 보임 (한 줄 없음)
class PlanPaywallFooter extends StatelessWidget {
  const PlanPaywallFooter({
    super.key,
    required this.selectedOffer,
    required this.isLoading,
    required this.onConfirm,
    required this.bottomInset,
  });

  /// 고른 상품 (못 불러왔으면 null)
  final PlanOffer? selectedOffer;
  final bool isLoading;

  /// null 이면 꺼짐 (상품 없음 · 결제 진행 중)
  final VoidCallback? onConfirm;

  /// 홈 표시줄 높이 (폰 시트만, 태블릿 카드는 0)
  final double bottomInset;

  /// 위 12 · 버튼 > 한 줄 8 · 아래 16 + 홈 표시줄
  static const _padTop = 12.0;
  static const _buttonToNotice = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    final offer = selectedOffer;
    final trial = offer?.freeTrial;
    final isPlayStore = defaultTargetPlatform == TargetPlatform.android;
    return Container(
      color: colors.background,
      padding: EdgeInsets.fromLTRB(space.buttonMarginH.w, _padTop.h, space.buttonMarginH.w, space.md.h + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElumButton(
            label: trial == null ? l10n.planSubscribe : l10n.planStartFreeTrial(planTrialLabel(l10n, trial)),
            labelStyle: context.typo.proPlanCtaLabel,
            loading: isLoading,
            onPressed: onConfirm,
          ),
          if (offer != null) ...[
            SizedBox(height: _buttonToNotice.h),
            _notice(context, planCtaNotice(l10n, offer, isPlayStore: isPlayStore)),
          ],
        ],
      ),
    );
  }

  /// 낱말 중간에서 꺾이지 않게 (`않아 / 요`)
  Widget _notice(BuildContext context, String notice) => Text(
    keepWords(notice, locale: context.appLocale),
    semanticsLabel: notice,
    textAlign: TextAlign.center,
    style: context.typo.proPlanFinePrint.copyWith(color: context.colors.textSecondary),
  );
}

/// 애플 필수 안내: 자동 갱신·청구 · (체험 상품이 있으면) 체험 중 해지 · 해지 방법 (스토어별 문장, 법적 문구라 그대로)
class PlanLegalNotice extends StatelessWidget {
  const PlanLegalNotice({super.key, this.hasFreeTrial = false});

  /// 체험이 붙은 상품이 보이는가 (가격을 못 불러왔으면 false)
  final bool hasFreeTrial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final style = context.typo.proPlanFinePrint.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.xs.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isAndroid ? l10n.planLegalBillingPlayStore : l10n.planLegalBillingAppStore,
            style: style,
          ),
          if (hasFreeTrial) ...[
            SizedBox(height: context.space.xs.h),
            Text(
              isAndroid ? l10n.planLegalTrialPlayStore : l10n.planLegalTrialAppStore,
              style: style,
            ),
          ],
          SizedBox(height: context.space.xs.h),
          Text(
            isAndroid ? l10n.planLegalCancelPlayStore : l10n.planLegalCancelAppStore,
            style: style,
          ),
        ],
      ),
    );
  }
}

/// 글자 버튼 줄: 이용약관 · 개인정보처리방침 · 구매 복원 (가격을 못 불러와도 늘 보임)
class PlanLinksRow extends StatelessWidget {
  const PlanLinksRow({
    super.key,
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.onRestoreTap,
  });

  final VoidCallback? onTermsTap;
  final VoidCallback? onPrivacyTap;
  final VoidCallback? onRestoreTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: context.space.xs.w,
      children: [
        ElumTextLink(label: l10n.planTermsOfUse, onTap: onTermsTap),
        ElumTextLink(label: l10n.planPrivacyPolicy, onTap: onPrivacyTap),
        ElumTextLink(label: l10n.planRestore, onTap: onRestoreTap),
      ],
    );
  }
}
