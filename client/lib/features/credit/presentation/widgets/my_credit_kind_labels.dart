import 'package:flutter/painting.dart' show Color;

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/credit_breakdown.dart';
import '../../domain/credit_period_unit.dart';

/// 내 크레딧 종류별 표시: 이름 · 끝나는 때 · 그림 · 색 (종류 분기는 이 파일 한 곳)
extension CreditKindLabels on CreditBreakdownLine {
  /// `주간` · `월간` · `보너스` · `구매`
  String kindName(AppLocalizations l10n, CreditPeriodUnit periodUnit) => switch (kind) {
    CreditKind.periodic => periodUnit.isMonth ? l10n.myCreditKindPeriodicMonth : l10n.myCreditKindPeriodicWeek,
    CreditKind.bonus => l10n.myCreditKindBonus,
    CreditKind.purchased => l10n.myCreditKindPurchased,
  };

  /// 주기는 다시 채워지는 때, 보너스는 `{날짜}까지`(없으면 제한 없음), 구매는 제한 없음
  String endLabel(AppLocalizations l10n, CreditPeriodUnit periodUnit) {
    final end = expiresAt;
    return switch (kind) {
      CreditKind.periodic => periodUnit.isMonth ? l10n.myCreditRefillMonth : l10n.myCreditRefillWeek,
      CreditKind.bonus => end == null ? l10n.myCreditNoExpiry : l10n.myCreditUntilDate(end.month, end.day),
      CreditKind.purchased => l10n.myCreditNoExpiry,
    };
  }

  String get pictureAsset => switch (kind) {
    CreditKind.periodic => AppAssets.creditTicket,
    CreditKind.bonus => AppAssets.creditTicketBonus,
    CreditKind.purchased => AppAssets.creditTicketPurchased,
  };

  /// 게이지 조각 색
  Color colorOf(AppColors colors) => switch (kind) {
    CreditKind.periodic => colors.creditKindPeriodic,
    CreditKind.bonus => colors.creditKindBonus,
    CreditKind.purchased => colors.creditKindPurchased,
  };
}
