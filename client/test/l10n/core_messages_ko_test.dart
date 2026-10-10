import 'package:elum/core/l10n/l10n_context.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 옮긴 공용 문구가 옛 한국어와 같다 — 코드가 조립하던 것(보간·접두)은 값으로 고정한다.
void main() {
  final ko = lookupAppLocalizations(const Locale('ko'));

  test('다시 시도 — 에러 코드가 있으면 괄호로 붙는다', () {
    expect(ko.commonRetryWithCode('E-NET-OFFLINE'), '다시 시도 (E-NET-OFFLINE)');
  });

  test('코치마크 낭독 문구', () {
    expect(
      ko.coachStepLabel(2, 3, '이룸이가 수행할 새로운 일과를 만들 수 있어요'),
      '안내 2/3. 이룸이가 수행할 새로운 일과를 만들 수 있어요',
    );
    expect(ko.coachStepLabel(10, 12, '끝'), '안내 10/12. 끝');
  });
}
