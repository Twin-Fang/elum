import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_sheet_action_row.dart';
import '../../../core/widgets/show_failure.dart';
import '../../member/application/plan_access.dart';
import '../application/plan_purchase_notifier.dart';
import '../application/plan_status_providers.dart';
import '../application/plan_store_catalog.dart';
import '../application/store_purchase_coordinator.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_error_code.dart';
import '../domain/plan_purchase_state.dart';
import '../domain/plan_benefit.dart';
import 'plan_actions.dart';
import 'plan_offer_views.dart';
import 'plan_state_views.dart';

/// 요금제 화면 내용 (폰 시트 · 태블릿 카드 공통): 이미 Pro > 결제 단계 안내 > 혜택·기간·결제 버튼·필수 안내
class PlanPaywallBody extends ConsumerStatefulWidget {
  const PlanPaywallBody({super.key, this.highlight});

  /// 혜택 묶음 맨 위로 올릴 혜택
  final PlanBenefit? highlight;

  @override
  ConsumerState<PlanPaywallBody> createState() => _PlanPaywallBodyState();
}

class _PlanPaywallBodyState extends ConsumerState<PlanPaywallBody> {
  /// 처음 고른 기간. 더 비싼 쪽을 미리 고르지 않음 (보호자가 직접 고르게)
  PlanPeriod _selectedPeriod = PlanPeriod.monthly;

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
        return PlanStateMessage(
          title: l10n.planActivatedTitle,
          body: planStatusLabel(l10n, ref.watch(planStatusProvider)),
          primaryLabel: l10n.commonConfirm,
          onPrimary: close,
        );
      case PlanPurchasePhase.waitingForStoreApproval:
        return PlanStateMessage(
          title: l10n.planStorePendingTitle,
          body: l10n.planStorePendingBody,
          primaryLabel: l10n.commonClose,
          onPrimary: close,
        );
      case PlanPurchasePhase.verifying:
        return PlanProgressLine(label: l10n.planVerifying);
      case PlanPurchasePhase.verificationPending:
        return PlanStateMessage(
          title: l10n.planVerificationPendingTitle,
          body: l10n.planVerificationPendingBody,
          errorCode: flow.failureCode == null ? null : _badgeOf(flow),
          secondaryLabel: l10n.commonClose,
          onSecondary: close,
          primaryLabel: l10n.planVerificationRetry,
          onPrimary: coordinator.retryVerification,
        );
      case PlanPurchasePhase.notActivated:
        return PlanStateMessage(
          title: l10n.planNotActivatedTitle,
          body: l10n.planNotActivatedBody,
          errorCode: _badgeOf(flow),
          secondaryLabel: l10n.commonClose,
          onSecondary: close,
          primaryLabel: l10n.planManageSubscription,
          onPrimary: () => openSubscriptionManagement(context, ref),
        );
      case PlanPurchasePhase.idle:
      case PlanPurchasePhase.purchasing:
      case PlanPurchasePhase.failed:
        return isPro ? _alreadyPro(context) : _offers(context, flow);
    }
  }

  /// 이미 Pro: 지금 상태 + 구독 관리(스토어 결제일 때) + 구매 복원 링크
  Widget _alreadyPro(BuildContext context) {
    final l10n = context.l10n;
    final isStorePurchase = ref.watch(memberSubscriptionProvider)?.isStorePurchase ?? false;
    return Column(
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
    );
  }

  /// 고르는 화면: 혜택 > 기간·가격 (불러오는 중 · 실패) > 닫기·결제 버튼 > 필수 안내 > 링크
  ///
  /// 닫기는 가격 상태와 무관하게 늘 보임 (#1167: 큰 글자에서 시트 위 띠가 거의 사라져 빠져나갈 길이 없었음)
  Widget _offers(BuildContext context, PlanPurchaseState flow) {
    final l10n = context.l10n;
    final catalogAsync = ref.watch(planCatalogProvider);
    final catalog = catalogAsync.value;
    final hasCatalog = catalog != null && catalog.hasOffers;
    final selected = hasCatalog ? (catalog.offerFor(_selectedPeriod) ?? catalog.offers.first) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanBenefitsGroup(highlight: widget.highlight),
        SizedBox(height: context.space.md.h),
        if (hasCatalog && selected != null)
          PlanOffersGroup(
            catalog: catalog,
            selectedPeriod: selected.period,
            onSelected: flow.isBusy ? null : (period) => setState(() => _selectedPeriod = period),
          )
        else if (catalogAsync.hasError)
          ElumErrorView(
            message: l10n.planPriceFailed,
            errorCode: PlanErrorCode.price,
            onRetry: () => ref.invalidate(planCatalogProvider),
            compact: true,
          )
        else
          PlanProgressLine(label: l10n.planPriceLoading),
        SizedBox(height: context.space.md.h),
        _actions(context, flow, selected),
        SizedBox(height: context.space.md.h),
        PlanLegalNotice(hasFreeTrial: hasCatalog && catalog.hasAnyFreeTrial),
        SizedBox(height: context.space.sm.h),
        _links(context, isBusy: flow.isBusy),
      ],
    );
  }

  /// 시트 버튼 줄: `닫기` + 결제 (고른 상품에 체험이 있으면 `7일 무료 체험 시작하기`). 상품을 못 불러왔으면 결제만 꺼짐
  Widget _actions(BuildContext context, PlanPurchaseState flow, PlanOffer? selected) {
    final l10n = context.l10n;
    final trial = selected?.freeTrial;
    return ElumSheetActionRow(
      cancelLabel: l10n.commonClose,
      onCancel: Navigator.of(context).pop,
      confirmLabel: trial == null ? l10n.planSubscribe : l10n.planStartFreeTrial(planTrialLabel(context, trial)),
      isLoading: flow.isBusy,
      onConfirm: selected != null && flow.canStartPurchase
          ? () => confirmGuardianAndBuy(context, ref, selected)
          : null,
    );
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
