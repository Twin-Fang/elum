import '../../../l10n/app_localizations.dart';

/// 크레딧이 다시 채워지는 주기 — 서버 `periodUnit` (`WEEK` · `MONTH`).
///
/// 크레딧 문구는 단위별 분기를 모두 여기서 고른다 (화면은 문구를 직접 고르지 않음).
enum CreditPeriodUnit {
  week,
  month;

  /// 없거나 모르는 값은 `WEEK`
  static CreditPeriodUnit fromWire(Object? raw) =>
      raw == 'MONTH' ? CreditPeriodUnit.month : CreditPeriodUnit.week;

  bool get isMonth => this == CreditPeriodUnit.month;

  /// `이번 주 AI 생성` / `이번 달 AI 생성`
  String cardTitle(AppLocalizations l10n) =>
      isMonth ? l10n.creditCardTitleMonth : l10n.creditCardTitle;

  /// 카드를 불러오는 중 낭독 문구
  String cardLoading(AppLocalizations l10n) =>
      isMonth ? l10n.creditCardLoadingMonth : l10n.creditCardLoading;

  /// 크레딧을 다 썼다는 한 줄
  String exhausted(AppLocalizations l10n) =>
      isMonth ? l10n.creditExhaustedMonth : l10n.creditExhausted;

  /// 시각을 모를 때 쓰는 다음 초기화 날
  String resetFallback(AppLocalizations l10n) =>
      isMonth ? l10n.creditResetFallbackMonth : l10n.creditResetFallback;

  /// 크레딧 더 받기 시트 제목 (다 썼을 때)
  String topUpExhaustedTitle(AppLocalizations l10n) =>
      isMonth ? l10n.creditTopUpTitleExhaustedMonth : l10n.creditTopUpTitleExhausted;

  /// 요금제 혜택 줄
  String planBenefitMoreCredits(AppLocalizations l10n) =>
      isMonth ? l10n.planBenefitMoreMonthlyCredits : l10n.planBenefitMoreWeeklyCredits;

  /// 내 정보 내 요금제 카드(Free) 한 줄
  String myPlanFreeBody(AppLocalizations l10n) =>
      isMonth ? l10n.myPlanFreeBodyMonth : l10n.myPlanFreeBodyWeek;

  /// 알림 켜기 안내 셋째 줄 (주간 리포트 권한 없을 때)
  String notificationIntroCreditRefilled(AppLocalizations l10n) =>
      isMonth ? l10n.notificationIntroCreditRefilledMonth : l10n.notificationIntroCreditRefilledWeek;
}
