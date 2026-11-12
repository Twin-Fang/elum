import '../../../../core/assets/app_assets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/credit_breakdown.dart';
import '../../domain/credit_period_unit.dart';

/// 내 크레딧 종류별 표시: 이름 · 그림 (종류 분기는 이 파일 한 곳)
extension CreditKindLabels on CreditBreakdownLine {
  /// `주간` · `월간` · `보너스` · `산 크레딧`
  String kindName(AppLocalizations l10n, CreditPeriodUnit periodUnit) => switch (kind) {
    CreditKind.periodic => periodUnit.isMonth ? l10n.myCreditKindPeriodicMonth : l10n.myCreditKindPeriodicWeek,
    CreditKind.bonus => l10n.myCreditKindBonus,
    CreditKind.purchased => l10n.myCreditKindPurchased,
  };

  String get pictureAsset => switch (kind) {
    CreditKind.periodic => AppAssets.creditTicket,
    CreditKind.bonus => AppAssets.creditTicketBonus,
    CreditKind.purchased => AppAssets.creditTicketPurchased,
  };
}
