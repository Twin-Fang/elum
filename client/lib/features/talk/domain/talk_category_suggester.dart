import '../../../l10n/app_localizations.dart';
import '../../guardian/domain/routine_template.dart';
import '../../guardian/domain/routine_template_catalog.dart';

// 낱말로 치는 최소 글자 수 (한 글자 조사·접속사 제외)
const _minimumWordLength = 2;

/// 일과 제목 > 이야기 분류 추천: 예시 일과 이름과 겹치는 낱말이 가장 많은 일과의 분류
/// 낱말은 공백 기준·2글자 이상, 같은 수면 목록 앞쪽 일과가 이긴다. 겹침이 없으면 null
RoutineTemplateCategory? suggestTalkCategory(
  String routineTitle,
  AppLocalizations l10n,
) {
  final titleWords = _wordsOf(routineTitle);
  if (titleWords.isEmpty) return null;

  RoutineTemplateCategory? bestCategory;
  var bestCommonWordCount = 0;
  for (final template in routineTemplates) {
    final templateWords = _wordsOf(template.textOf(l10n));
    final commonWordCount = titleWords.intersection(templateWords).length;
    if (commonWordCount > bestCommonWordCount) {
      bestCommonWordCount = commonWordCount;
      bestCategory = template.category;
    }
  }
  return bestCategory;
}

Set<String> _wordsOf(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((word) => word.length >= _minimumWordLength)
    .toSet();
