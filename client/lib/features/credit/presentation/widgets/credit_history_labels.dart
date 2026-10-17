import '../../../../l10n/app_localizations.dart';
import '../../domain/credit_history.dart';

/// 내역 줄의 종류 문구. 모르는 종류는 증감 부호로 일반 문구를 쓴다.
String creditHistoryKindLabel(AppLocalizations l10n, CreditHistoryEntry entry) {
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
    CreditHistoryKind.expired => l10n.creditHistoryKindExpired,
    CreditHistoryKind.adjusted => l10n.creditHistoryKindAdjusted,
  };
}
