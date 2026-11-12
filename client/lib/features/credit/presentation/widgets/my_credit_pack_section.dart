import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_button.dart';
import '../../../../core/widgets/elum_error_code_text.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_spinner.dart';
import '../../../../core/widgets/mint_gradient_button.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/application/credit_pack_catalog.dart';
import '../../../subscription/application/credit_purchase_coordinator.dart';
import '../../../subscription/application/credit_purchase_notifier.dart';
import '../../domain/credit_pack.dart';
import '../../domain/credit_purchase.dart';
import '../credit_purchase_actions.dart';
import 'my_credit_pack_tile.dart';

/// 꾸러미 구역: 제목 > 칸 3개 > 사기 버튼(개수 + 값) > 안내. 판매가 꺼졌거나 꾸러미가 비면 통째로 숨김
///
/// 상태: 값 불러오는 중 / 값 실패(`E-CREDIT-PACK-PRICE` + 다시 하기) / 고르는 중 / 결제·확인 중(버튼 로딩) / 확인 대기(`다시 확인하기`)
class MyCreditPackSection extends ConsumerStatefulWidget {
  const MyCreditPackSection({super.key});

  @override
  ConsumerState<MyCreditPackSection> createState() => _MyCreditPackSectionState();
}

class _MyCreditPackSectionState extends ConsumerState<MyCreditPackSection> {
  /// 고른 꾸러미 상품 id (처음엔 인기 칸, 없으면 첫 칸)
  String? _selectedProductId;

  static const _tileGap = 10.0;

  /// 칸 위 할인율 · 아래 인기 알약이 칸 밖으로 걸치는 만큼의 여백
  static const _pillRoom = 12.0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(creditPackOffersProvider);
    final space = context.space;
    final colors = context.colors;
    final isPro = ref.watch(planAccessProvider.select((access) => access.isPro));
    final l10n = context.l10n;
    return switch (async) {
      AsyncData(value: final offers) when offers.isEmpty => const SizedBox.shrink(),
      AsyncData(value: final offers) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(left: space.xs.w),
            child: Text(
              isPro ? l10n.myCreditPackLabelPro : l10n.myCreditPackLabelFree,
              style: context.typo.settingsGroupLabel.copyWith(color: colors.settingsGroupLabel),
            ),
          ),
          SizedBox(height: space.md.h + _pillRoom.h),
          _tiles(context, offers),
          SizedBox(height: space.md.h + _pillRoom.h),
          _buyArea(context, offers),
        ],
      ),
      AsyncError() => ElumErrorView(
        message: l10n.myCreditPackPriceFailed,
        errorCode: CreditPurchaseErrorCode.packPrice,
        onRetry: () => ref.invalidate(creditPackOffersProvider),
        compact: true,
      ),
      _ => Padding(
        padding: EdgeInsets.symmetric(vertical: space.lg.h),
        child: Center(child: ElumSpinner(size: 32.w, strokeWidth: 3)),
      ),
    };
  }

  /// 칸 3개 나란히 (개수 적은 순)
  Widget _tiles(BuildContext context, List<CreditPackOffer> offers) {
    final selectedId = _selected(offers).pack.productId;
    final flow = ref.watch(creditPurchaseStateProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (index, offer) in offers.indexed) ...[
          if (index > 0) SizedBox(width: _tileGap.w),
          Expanded(
            child: MyCreditPackTile(
              offer: offer,
              index: index,
              listPriceLabel: _listPriceLabel(context, offer),
              isSelected: offer.pack.productId == selectedId,
              onTap: flow.isBusy ? null : () => setState(() => _selectedProductId = offer.pack.productId),
            ),
          ),
        ],
      ],
    );
  }

  /// 사기 버튼 + 안내. 결제는 됐는데 확인 전이면 `다시 확인하기` 안내로 바뀜 (다시 결제시키지 않음)
  Widget _buyArea(BuildContext context, List<CreditPackOffer> offers) {
    final flow = ref.watch(creditPurchaseStateProvider);
    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    if (flow.phase == CreditPurchasePhase.needsRecheck) {
      final code = AppFailure.of(flow.failure).badgeOr(flow.failureCode ?? CreditPurchaseErrorCode.verify);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.myCreditPurchaseRecheckTitle, textAlign: TextAlign.center, style: context.typo.creditTitle.copyWith(color: colors.textPrimary)),
          SizedBox(height: space.xs.h),
          Text(l10n.myCreditPurchaseRecheckBody, textAlign: TextAlign.center, style: context.typo.creditBody.copyWith(color: colors.textSecondary)),
          SizedBox(height: space.xs.h),
          ElumErrorCodeText(code),
          SizedBox(height: space.sm.h),
          ElumButton(
            label: l10n.planVerificationRetry,
            onPressed: ref.read(creditPurchaseCoordinatorProvider).retryVerification,
          ),
        ],
      );
    }
    final selected = _selected(offers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MintGradientButton(
          label: l10n.myCreditPackBuy(selected.pack.credits, selected.price.label),
          isLoading: flow.isBusy,
          onTap: flow.canStartPurchase
              ? () => confirmGuardianAndBuyCredits(context, ref, selected.pack)
              : null,
        ),
        SizedBox(height: space.sm.h),
        Text(
          l10n.myCreditPackNoExpiryNote,
          textAlign: TextAlign.center,
          style: context.typo.creditCaption.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  /// 고른 칸: 고른 것이 목록에 있으면 그것, 아니면 인기 칸, 그것도 없으면 첫 칸
  CreditPackOffer _selected(List<CreditPackOffer> offers) {
    for (final offer in offers) {
      if (offer.pack.productId == _selectedProductId) return offer;
    }
    return offers.firstWhere((offer) => offer.pack.isPopular, orElse: () => offers.first);
  }

  /// 원래 값 > 스토어 통화 모양 (`₩8,700`, 통화 소수 자리에서 반올림). 할인 없으면 null
  String? _listPriceLabel(BuildContext context, CreditPackOffer offer) {
    final listPrice = offer.listPrice;
    final currencyCode = offer.price.currencyCode;
    if (listPrice == null || currencyCode == null) return null;
    return NumberFormat.simpleCurrency(locale: context.l10n.localeName, name: currencyCode).format(listPrice);
  }
}
