import 'package:elum/features/guardian/domain/routine_template.dart';
import 'package:elum/features/guardian/domain/routine_template_catalog.dart';
import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 깨지면: 카테고리를 눌렀는데 빈 목록이 뜨거나, 처음 쓰는 보호자 추천이 뒤에 묻힌다
  test('모든 카테고리에 예시가 있고 처음이라면 추천이 앞', () {
    for (final category in RoutineTemplateCategory.values) {
      final templates = routineTemplatesOf(category);
      expect(templates, isNotEmpty, reason: category.name);
      final firstOther = templates.indexWhere((t) => !t.isBeginnerFriendly);
      final lastBeginner = templates.lastIndexWhere((t) => t.isBeginnerFriendly);
      if (firstOther >= 0 && lastBeginner >= 0) {
        expect(lastBeginner, lessThan(firstOther), reason: category.name);
      }
    }
  });

  // 깨지면: 예시를 골랐는데 입력칸이 비어 AI 에 빈 문장이 간다
  test('모든 예시에 이름과 입력 문장이 있다 (id 중복 없음)', () {
    final l10n = lookupAppLocalizations(const Locale('ko'));
    final ids = <String>{};
    for (final template in routineTemplates) {
      expect(ids.add(template.id), isTrue, reason: template.id);
      expect(template.textOf(l10n).trim(), isNotEmpty, reason: template.id);
      expect(template.promptOf(l10n).trim(), isNotEmpty, reason: template.id);
    }
  });
}
