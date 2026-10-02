import 'dart:convert';
import 'dart:io';

import 'package:elum/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 번역이 빠진 키가 화면을 깨지 않는다 (Review Focus).
///
/// gen-l10n 은 빠진 키를 템플릿(`ko`) 문구로 채운다. 스펙의 `en → ko` 순서와 달리 `ko` 로
/// 곧바로 간다(이 계획 결정 D1). 번역이 채워진 언어는 자기 문구를 주므로, **ARB 파일에 그 키가
/// 없는 언어만** 검사한다 — 번역이 들어와도 이 테스트가 깨지지 않는다.
void main() {
  test('ARB 에 키가 없는 언어는 ko 문구를 준다 — 예외도 빈 문자열도 아니다', () {
    final ko = lookupAppLocalizations(const Locale('ko'));
    for (final code in ['en', 'ja', 'zh', 'es']) {
      final arb = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
      // 번역이 채워진 언어는 자기 문구를 주므로 건너뛴다 (골격 단계에서는 전부 검사된다)
      if (arb.containsKey('commonConfirm')) continue;

      final l10n = lookupAppLocalizations(Locale(code));
      expect(l10n.commonConfirm, ko.commonConfirm, reason: code);
      expect(l10n.commonConfirm, isNotEmpty, reason: code);
    }
  });
}
