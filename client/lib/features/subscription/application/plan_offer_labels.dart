import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/plan_catalog.dart';

/// 요금제 화면 · Pro 미리 보기가 함께 쓰는 상품 문구 (가격·기간은 스토어 값 그대로, 앱이 다시 만들지 않음)

/// 체험 기간 (`7일` · `1주` · `1개월` · `1년`, 스토어 단위 그대로)
String planTrialLabel(AppLocalizations l10n, PlanFreeTrial trial) => switch (trial.unit) {
  PlanTrialUnit.day => l10n.planTrialDays(trial.unitCount),
  PlanTrialUnit.week => l10n.planTrialWeeks(trial.unitCount),
  PlanTrialUnit.month => l10n.planTrialMonths(trial.unitCount),
  PlanTrialUnit.year => l10n.planTrialYears(trial.unitCount),
};

/// 기간 이름 (`1개월` · `1년`)
String planPeriodName(AppLocalizations l10n, PlanPeriod period) => switch (period) {
  PlanPeriod.monthly => l10n.planPeriodMonthly,
  PlanPeriod.yearly => l10n.planPeriodYearly,
};

/// 가격 뒤 단위 (`/년` · `/월`)
String planPriceUnit(AppLocalizations l10n, PlanPeriod period) => l10n.planPriceUnit(period.name);

/// 1년 ÷ 12 > 스토어 통화 모양 (`₩4,917` · `$3.33`, 통화 소수 자리에서 반올림)
String planMonthlyEquivalentLabel(AppLocalizations l10n, PlanYearlySavings savings) {
  final format = NumberFormat.simpleCurrency(locale: l10n.localeName, name: savings.currencyCode);
  return l10n.planMonthlyEquivalent(format.format(savings.monthlyEquivalent));
}

/// 결제 버튼 아래 한 줄: 체험 > `7일 뒤 ₩59,000/년 자동 결제 · …해지 조건` (스토어별), 체험 없음 > `₩59,000/년 자동 갱신 · 언제든 해지`
///
/// App Store 는 체험 끝나기 24시간 전까지 해지해야 청구되지 않아 문장을 나눔
String planCtaNotice(AppLocalizations l10n, PlanOffer offer, {required bool isPlayStore}) {
  final unit = planPriceUnit(l10n, offer.period);
  final trial = offer.freeTrial;
  if (trial == null) return l10n.planCtaRenewNotice(offer.priceLabel, unit);
  final trialLabel = planTrialLabel(l10n, trial);
  return isPlayStore
      ? l10n.planCtaTrialNoticePlayStore(trialLabel, offer.priceLabel, unit)
      : l10n.planCtaTrialNoticeAppStore(trialLabel, offer.priceLabel, unit);
}
