import '../../../../l10n/app_localizations.dart';
import '../../domain/credit_history.dart';
import '../../domain/credit_period_unit.dart';

/// 내역 줄의 종류 문구 (짧은 제목). 모르는 종류는 증감 부호로 일반 문구를 쓴다.
/// 만료는 주기(주·달)에 따라 `지난 주 크레딧 정리` · `지난 달 크레딧 정리`
String creditHistoryKindLabel(AppLocalizations l10n, CreditHistoryEntry entry, CreditPeriodUnit periodUnit) {
  final kind = entry.kind;
  if (kind == null) {
    return entry.delta > 0
        ? l10n.creditHistoryKindOtherGrant
        : l10n.creditHistoryKindUnknownSpend;
  }
  return switch (kind) {
    CreditHistoryKind.routineText => l10n.creditHistoryKindRoutineText,
    // 그림 수를 모르면(옛 기록) 장수 없이 일반 문구로 말한다
    CreditHistoryKind.cardImages =>
      entry.cardCount == null
          ? l10n.creditHistoryKindCardImage
          : l10n.creditHistoryKindCardImages(entry.cardCount!),
    CreditHistoryKind.cardImage => l10n.creditHistoryKindCardImage,
    CreditHistoryKind.imageRegenerate => l10n.creditHistoryKindImageRegenerate,
    CreditHistoryKind.weeklyGrant => l10n.creditHistoryKindWeeklyGrant,
    CreditHistoryKind.adReward => l10n.creditHistoryKindAdReward,
    CreditHistoryKind.adminBonus => l10n.creditHistoryKindAdminBonus,
    CreditHistoryKind.otherGrant => l10n.creditHistoryKindOtherGrant,
    CreditHistoryKind.expired =>
      periodUnit.isMonth ? l10n.creditHistoryExpiredMonthTitle : l10n.creditHistoryExpiredWeekTitle,
    CreditHistoryKind.adjusted => l10n.creditHistoryAdjustedTitle,
  };
}

/// 제목만으로 이유를 모르는 줄의 부제 (만료 · 조정). 그 외 종류는 null > 부제 줄 없음
String? creditHistoryReasonLabel(AppLocalizations l10n, CreditHistoryEntry entry, CreditPeriodUnit periodUnit) =>
    switch (entry.kind) {
      CreditHistoryKind.expired =>
        periodUnit.isMonth ? l10n.creditHistoryExpiredMonthReason : l10n.creditHistoryExpiredWeekReason,
      CreditHistoryKind.adjusted => l10n.creditHistoryAdjustedReason,
      _ => null,
    };
