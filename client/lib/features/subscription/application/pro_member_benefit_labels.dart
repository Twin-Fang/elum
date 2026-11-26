import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../credit/application/credit_costs.dart';
import '../../member/application/plan_access.dart';
import '../domain/plan_benefit.dart';
import '../presentation/plan_benefit_cards.dart' show planBenefitLabel;

/// Pro 회원 카드 알약 후보 3개 (짧은 문구 먼저)
const _memberCardBenefits = [
  PlanBenefit.freeRoutineText,
  PlanBenefit.adsRemoved,
  PlanBenefit.freeImageRegenerate,
];

/// Pro 회원 카드 혜택 알약 문구 (build 안에서 부름): 후보 3개 중 지금 계정이 쓸 수 있는 것만, 다 꺼졌으면 빈 목록
///
/// 내 정보 내 요금제 카드 · 내 요금제 시트 머리가 같은 알약을 보임 (#1516)
List<String> watchProMemberBenefitLabels(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final access = ref.watch(planAccessProvider);
  final periodUnit = ref.watch(creditPeriodUnitProvider);
  // 다시 그리기 알약 `하루 N번까지` (서버 한도 모르면 숫자 없는 문구)
  final freeRegenerateDailyCap = ref.watch(freeImageRegenerateDailyCapProvider);
  return [
    for (final benefit in _memberCardBenefits)
      if (access.canUseBenefit(benefit))
        planBenefitLabel(l10n, benefit, periodUnit, freeRegenerateDailyCap: freeRegenerateDailyCap),
  ];
}
