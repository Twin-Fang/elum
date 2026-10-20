import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';

/// 예시 일과 카테고리 6개 (#777, 실증 1차 요구: 자조·학습·사회참여·마음 등으로 나눠 달라)
enum RoutineTemplateCategory {
  selfCare('SELF_CARE'),
  dailyFlow('DAILY_FLOW'),
  household('HOUSEHOLD'),
  community('COMMUNITY'),
  learning('LEARNING'),
  feelings('FEELINGS');

  const RoutineTemplateCategory(this.serverValue);

  /// 서버 TalkCategory 와 같은 이름 (CrossStackContractTest 가 대조)
  final String serverValue;

  /// 서버 값 > 카테고리 (모르는 값·null 은 null)
  static RoutineTemplateCategory? fromServer(String? raw) {
    for (final category in values) {
      if (category.serverValue == raw) return category;
    }
    return null;
  }

  /// 카테고리 > 화면 이름
  String labelOf(AppLocalizations l10n) => switch (this) {
    selfCare => l10n.routineTemplateCategorySelfCare,
    dailyFlow => l10n.routineTemplateCategoryDailyFlow,
    household => l10n.routineTemplateCategoryHousehold,
    community => l10n.routineTemplateCategoryCommunity,
    learning => l10n.routineTemplateCategoryLearning,
    feelings => l10n.routineTemplateCategoryFeelings,
  };

  /// 카테고리 > 한 줄 설명
  String hintOf(AppLocalizations l10n) => switch (this) {
    selfCare => l10n.routineTemplateCategorySelfCareHint,
    dailyFlow => l10n.routineTemplateCategoryDailyFlowHint,
    household => l10n.routineTemplateCategoryHouseholdHint,
    community => l10n.routineTemplateCategoryCommunityHint,
    learning => l10n.routineTemplateCategoryLearningHint,
    feelings => l10n.routineTemplateCategoryFeelingsHint,
  };
}

/// 예시 일과 1건: 이름(목록) · 문장(입력칸) · 처음 쓰는 보호자 추천 여부
///
/// 문구는 휴대폰 언어로 부를 때마다 만든다 (`app_ko.arb` 가 원본).
@immutable
class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.category,
    required this.icon,
    required this.isBeginnerFriendly,
    required String Function(AppLocalizations) text,
    required String Function(AppLocalizations) prompt,
  }) : _text = text,
       _prompt = prompt;

  final String id;
  final RoutineTemplateCategory category;

  /// 유니코드 이모지
  final String icon;

  /// 처음 해 보기 좋은 짧은 일과 (실증 1차: 초심자용과 숙련자용을 나눠 달라)
  final bool isBeginnerFriendly;

  final String Function(AppLocalizations) _text;
  final String Function(AppLocalizations) _prompt;

  String textOf(AppLocalizations l10n) => _text(l10n);

  /// 입력칸에 채울 문장 — AI 가 이 문장으로 과제분석(카드 쪼개기)을 한다
  String promptOf(AppLocalizations l10n) => _prompt(l10n);
}
