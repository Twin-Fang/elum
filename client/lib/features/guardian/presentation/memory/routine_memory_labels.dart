import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/routine_memory.dart';
import 'package:flutter/painting.dart' show Color;

/// 메모리 규칙 종류별 표시: 이름 · 줄 아이콘 · 원 색 · 찾은 수정에 맞는 말 (종류 분기는 이 파일 한 곳)
extension MemoryRuleTypeLabels on MemoryRuleType {
  String typeName(AppLocalizations l10n) => switch (this) {
    MemoryRuleType.word => l10n.memoryTypeWord,
    MemoryRuleType.split => l10n.memoryTypeSplit,
    MemoryRuleType.merge => l10n.memoryTypeMerge,
    MemoryRuleType.add => l10n.memoryTypeAdd,
    MemoryRuleType.remove => l10n.memoryTypeRemove,
    MemoryRuleType.manual => l10n.memoryTypeManual,
  };

  /// 일과를 보낸 직후 카드의 `{종류에 맞는 말}`
  String observationPhrase(AppLocalizations l10n) => switch (this) {
    MemoryRuleType.word => l10n.memoryObsWord,
    MemoryRuleType.split => l10n.memoryObsSplit,
    MemoryRuleType.merge => l10n.memoryObsMerge,
    MemoryRuleType.add => l10n.memoryObsAdd,
    MemoryRuleType.remove => l10n.memoryObsRemove,
    MemoryRuleType.manual => l10n.memoryObsManual,
  };

  String get iconAsset => switch (this) {
    MemoryRuleType.word => AppAssets.iconPencil,
    MemoryRuleType.manual => AppAssets.iconPencilEdit,
    MemoryRuleType.split || MemoryRuleType.merge || MemoryRuleType.add || MemoryRuleType.remove => AppAssets.iconPlayingCards,
  };

  Color circleColorOf(AppColors colors) => switch (this) {
    MemoryRuleType.word => colors.routineMemoryIconWord,
    MemoryRuleType.manual => colors.routineMemoryIconManual,
    MemoryRuleType.split || MemoryRuleType.merge || MemoryRuleType.add || MemoryRuleType.remove => colors.routineMemoryIconStructure,
  };
}
