import 'package:flutter/foundation.dart';

/// 나눈 카드 한 장의 글 (제목 + 한 문장 설명)
@immutable
class CardSplitDraft {
  const CardSplitDraft({required this.title, required this.description});

  final String title;
  final String description;

  /// 서버 응답 한 장 > 글. 제목이 비었거나 모양이 다르면 null
  static CardSplitDraft? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final title = json['title']?.toString().trim() ?? '';
    if (title.isEmpty) return null;
    return CardSplitDraft(title: title, description: json['description']?.toString().trim() ?? '');
  }

  Map<String, String> toJson() => {'title': title, 'description': description};
}

/// 카드 나누기 안 받기 결과: 나눈 안 또는 이미 짧음
sealed class CardSplitSuggestion {
  const CardSplitSuggestion();
}

/// 2~3장으로 나눈 안 (저장 전)
class CardSplitSuggested extends CardSplitSuggestion {
  const CardSplitSuggested(this.drafts);

  final List<CardSplitDraft> drafts;
}

/// 더 나눌 필요가 없는 카드
class CardSplitAlreadyShort extends CardSplitSuggestion {
  const CardSplitAlreadyShort();
}

/// 나눈 카드 수 범위 (서버 계약: 2~3장)
const cardSplitMinimumCount = 2;
const cardSplitMaximumCount = 3;
