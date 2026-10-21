import '../../../l10n/app_localizations.dart';
import '../../guardian/domain/routine_template.dart';
import '../../guardian/domain/routine_template_catalog.dart';

// 낱말로 치는 최소 글자 수 (한 글자 조사·접속사 제외)
const _minimumWordLength = 2;

// 낱말 점수: 정확히 같음 2, 앞 글자가 겹치거나 한쪽이 다른 쪽을 포함 1 (숙제하기 <-> 숙제, 양치 <-> 양치하기)
const _exactWordScore = 2;
const _partialWordScore = 1;

/// 일과 제목 > 이야기 분류 추천: 예시 일과 이름과 낱말 점수 합이 가장 높은 일과의 분류
/// 낱말은 공백 기준·2글자 이상, 제목 낱말마다 이름 낱말 중 최고점 1개만 센다. 동점이면 목록 앞쪽 일과, 0점이면 null
RoutineTemplateCategory? suggestTalkCategory(
  String routineTitle,
  AppLocalizations l10n,
) {
  final titleWords = _wordsOf(routineTitle);
  if (titleWords.isEmpty) return null;

  RoutineTemplateCategory? bestCategory;
  var bestScore = 0;
  for (final template in routineTemplates) {
    final templateWords = _wordsOf(template.textOf(l10n));
    final score = _totalScoreOf(titleWords, templateWords);
    if (score > bestScore) {
      bestScore = score;
      bestCategory = template.category;
    }
  }
  return bestCategory;
}

int _totalScoreOf(Set<String> titleWords, Set<String> templateWords) {
  var totalScore = 0;
  for (final titleWord in titleWords) {
    var bestWordScore = 0;
    for (final templateWord in templateWords) {
      final wordScore = _wordScoreOf(titleWord, templateWord);
      if (wordScore > bestWordScore) bestWordScore = wordScore;
    }
    totalScore += bestWordScore;
  }
  return totalScore;
}

int _wordScoreOf(String titleWord, String templateWord) {
  if (titleWord == templateWord) return _exactWordScore;
  final isPartialMatch =
      titleWord.contains(templateWord) ||
      templateWord.contains(titleWord) ||
      titleWord.substring(0, _minimumWordLength) ==
          templateWord.substring(0, _minimumWordLength);
  return isPartialMatch ? _partialWordScore : 0;
}

// 공백 기준 낱말 (소문자, 2글자 이상, 중복 제거)
Set<String> _wordsOf(String text) => text
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((word) => word.length >= _minimumWordLength)
    .toSet();
