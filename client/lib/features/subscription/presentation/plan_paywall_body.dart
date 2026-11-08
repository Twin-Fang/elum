import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/show_failure.dart';
import '../../member/application/plan_access.dart';
import '../application/plan_purchase_notifier.dart';
import '../application/plan_status_providers.dart';
import '../application/plan_store_catalog.dart';
import '../application/store_purchase_coordinator.dart';
import '../domain/plan_benefit.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_error_code.dart';
import '../domain/plan_purchase_state.dart';
import 'plan_actions.dart';
import 'plan_benefit_cards.dart';
import 'plan_offer_cards.dart';
import 'plan_offer_views.dart';
import 'plan_paywall_hero.dart';
import 'plan_paywall_scaffold.dart';
import 'plan_state_views.dart';

/// 요금제 화면 내용 (폰 시트 · 태블릿 카드 공통): 결제 단계 안내 > 이미 Pro > 고르는 화면 (머리 · 혜택 · 기간 · 필수 안내 + 바닥 결제 버튼)
class PlanPaywallBody extends ConsumerStatefulWidget {
  const PlanPaywallBody({super.key, this.highlight, required this.bottomInset});

  /// 혜택 묶음 맨 위로 올릴 혜택
  final PlanBenefit? highlight;

  /// 홈 표시줄 높이 (폰 시트만)
  final double bottomInset;

  @override
  ConsumerState<PlanPaywallBody> createState() => _PlanPaywallBodyState();
}

class _PlanPaywallBodyState extends ConsumerState<PlanPaywallBody> {
  /// 보호자가 고른 기간. null 이면 처음 골라 두는 1년 (#1189: 가장 많이 아끼는 쪽을 먼저 보여 줌)
  PlanPeriod? _selectedPeriod;

  /// 고르는 화면 사이 간격: 머리 > 혜택 0 (머리 아래 여백) · 묶음 사이 24 · 안내 > 링크 8 · 끝 24
  static const _sectionGap = 24.0;

  /// 결제 단계 안내 위 (✕ 자리)
  static const _messageTop = 56.0;

  @override
  Widget build(BuildContext context) {
    // 되돌릴 수 없는 실패는 팝업 1번 > 다시 고르는 화면
    ref.listen(planPurchaseStateProvider, (previous, next) {
      if (next.phase == PlanPurchasePhase.failed &&
          previous?.phase != PlanPurchasePhase.failed) {
        _showFailure(next);
      }
    });
    final flow = ref.watch(planPurchaseStateProvider);
    final isPro = ref.watch(planAccessProvider.select((access) => access.isPro));
    final l10n = context.l10n;
    final coordinator = ref.read(storePurchaseCoordinatorProvider);
    final close = Navigator.of(context).pop;

    switch (flow.phase) {
      case PlanPurchasePhase.activated:
        return _message(PlanStateMessage(
          title: l10n.planActivatedTitle,
          body: planStatusLabel(l10n, ref.watch(planStatusProvider)),
          primaryLabel: l10n.commonConfirm,
          onPrimary: close,
        ));
      case PlanPurchasePhase.waitingForStoreApproval:
        return _message(PlanStateMessage(
          title: l10n.planStorePendingTitle,
          body: l10n.planStorePendingBody,
          primaryLabel: l10n.commonClose,
          onPrimary: close,
        ));
      case PlanPurchasePhase.verifying:
        return _message(PlanProgressLine(label: l10n.planVerifying));
      case PlanPurchasePhase.verificationPending:
        return _message(PlanStateMessage(
          title: l10n.planVerificationPendingTitle,
          body: l10n.planVerificationPendingBody,
          errorCode: flow.failureCode == null ? null : _badgeOf(flow),
          secondaryLabel: l10n.commonClose,
          onSecondary: close,
          primaryLabel: l10n.planVerificationRetry,
          onPrimary: coordinator.retryVerification,
        ));
      case PlanPurchasePhase.notActivated:
        return _message(PlanStateMessage(
          title: l10n.planNotActivatedTitle,
          body: l10n.planNotActivatedBody,
          errorCode: _badgeOf(flow),
          secondaryLabel: l10n.commonClose,
          onSecondary: close,
          primaryLabel: l10n.planManageSubscription,
          onPrimary: () => openSubscriptionManagement(context, ref),
        ));
      case PlanPurchasePhase.idle:
      case PlanPurchasePhase.purchasing:
      case PlanPurchasePhase.failed:
        return isPro ? _alreadyPro(context) : _offers(context, flow);
    }
  }

  /// 결제 단계 안내 한 덩이 (바닥 버튼 없음, 안내가 버튼을 가짐)
  Widget _message(Widget message) => PlanPaywallScaffold(
    content: Padding(
      padding: EdgeInsets.fromLTRB(
        context.space.md.w,
        _messageTop.h,
        context.space.md.w,
        context.space.lg.h + widget.bottomInset,
      ),
      child: message,
    ),
  );

  /// 이미 Pro: 지금 상태 + 구독 관리(스토어 결제일 때) + 구매 복원 링크
  Widget _alreadyPro(BuildContext context) {
    final l10n = context.l10n;
    final isStorePurchase = ref.watch(memberSubscriptionProvider)?.isStorePurchase ?? false;
    return _message(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanStateMessage(
          title: l10n.planAlreadyProTitle,
          body: planStatusLabel(l10n, ref.watch(planStatusProvider)),
          secondaryLabel: isStorePurchase ? l10n.commonClose : null,
          onSecondary: Navigator.of(context).pop,
          primaryLabel: isStorePurchase ? l10n.planManageSubscription : l10n.commonConfirm,
          onPrimary: isStorePurchase
              ? () => openSubscriptionManagement(context, ref)
              : Navigator.of(context).pop,
        ),
        SizedBox(height: context.space.md.h),
        _links(context, isBusy: false),
      ],
    ));
  }

  /// 고르는 화면: 머리 > 혜택 묶음 > 기간 (불러오는 중 · 실패) > 필수 안내 > 링크 · 바닥에 결제 버튼
  ///
  /// ✕ 와 결제 버튼은 가격 상태와 무관하게 늘 보임 (#1167: 큰 글자에서 빠져나갈 길이 없었음)
  Widget _offers(BuildContext context, PlanPurchaseState flow) {
    final space = context.space;
    final catalogAsync = ref.watch(planCatalogProvider);
    final catalog = catalogAsync.value;
    final hasCatalog = catalog != null && catalog.hasOffers;
    final selected = hasCatalog ? _selectedOffer(catalog) : null;
    return PlanPaywallScaffold(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PlanPaywallHero(),
          Padding(
            padding: EdgeInsets.fromLTRB(space.md.w, 0, space.md.w, _sectionGap.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PlanBenefitCards(highlight: widget.highlight),
                SizedBox(height: _sectionGap.h),
                _offerSection(context, flow, catalogAsync, selected),
                SizedBox(height: _sectionGap.h),
                PlanLegalNotice(hasFreeTrial: hasCatalog && catalog.hasAnyFreeTrial),
                SizedBox(height: space.xs.h),
                _links(context, isBusy: flow.isBusy),
              ],
            ),
          ),
        ],
      ),
      footer: PlanPaywallFooter(
        selectedOffer: selected,
        isLoading: flow.isBusy,
        bottomInset: widget.bottomInset,
        onConfirm: selected != null && flow.canStartPurchase
            ? () => confirmGuardianAndBuy(context, ref, selected)
            : null,
      ),
    );
  }

  /// 기간 자리: 카드 · 실패(`E-PLAN-PRICE` + 다시 시도, 오프라인·시간 초과 포함) · 불러오는 중
  Widget _offerSection(
    BuildContext context,
    PlanPurchaseState flow,
    AsyncValue<PlanCatalog> catalogAsync,
    PlanOffer? selected,
  ) {
    final catalog = catalogAsync.value;
    if (catalog != null && selected != null) {
      return PlanOfferCards(
        catalog: catalog,
        selectedPeriod: selected.period,
        onSelected: flow.isBusy ? null : (period) => setState(() => _selectedPeriod = period),
      );
    }
    if (catalogAsync.hasError) {
      return ElumErrorView(
        message: context.l10n.planPriceFailed,
        errorCode: PlanErrorCode.price,
        onRetry: () => ref.invalidate(planCatalogProvider),
        compact: true,
      );
    }
    return PlanProgressLine(label: context.l10n.planPriceLoading);
  }

  /// 고른 기간의 상품 (안 골랐거나 그 상품이 없으면 처음 골라 두는 것)
  PlanOffer? _selectedOffer(PlanCatalog catalog) {
    final period = _selectedPeriod;
    return (period == null ? null : catalog.offerFor(period)) ?? catalog.recommendedOffer;
  }

  Widget _links(BuildContext context, {required bool isBusy}) => PlanLinksRow(
    onTermsTap: () => openTermsOfUse(context),
    onPrivacyTap: () => openPrivacyPolicy(context),
    onRestoreTap: isBusy ? null : () => restorePlanPurchases(context, ref),
  );

  Future<void> _showFailure(PlanPurchaseState state) async {
    final l10n = context.l10n;
    await showFailure(
      context,
      state.failure,
      title: switch (state.failureCode) {
        PlanErrorCode.account => l10n.planAccountFailedTitle,
        PlanErrorCode.verify => l10n.planVerifyFailedTitle,
        _ => l10n.planPurchaseFailedTitle,
      },
      fallback: l10n.planFailedFallback,
      fallbackCode: state.failureCode ?? PlanErrorCode.store,
    );
    if (!mounted) return;
    ref.read(planPurchaseStateProvider.notifier).apply(const PlanPurchaseEvent.failureShown());
  }

  static String _badgeOf(PlanPurchaseState state) =>
      AppFailure.of(state.failure).badgeOr(state.failureCode ?? PlanErrorCode.verify);
}
